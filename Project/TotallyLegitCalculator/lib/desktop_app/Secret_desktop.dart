import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'Calculator_desktop.dart';
//import 'Settings_desktop.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// Provider pro API službu
final apiServiceProvider = Provider((ref) => ApiService());

// Provider pro zprávy
final messagesProvider = StateNotifierProvider<MessagesNotifier, List<Message>>(
  (ref) {
    final apiService = ref.watch(apiServiceProvider);
    return MessagesNotifier(apiService);
  },
);

// Notifier pro zprávy
class MessagesNotifier extends StateNotifier<List<Message>> {
  final ApiService _apiService;
  Timer? _refreshTimer;

  MessagesNotifier(this._apiService) : super([]) {
    _loadInitialMessages();
    _startRefreshTimer();
  }

  Future<void> _loadInitialMessages() async {
    final messages = await _apiService.getMessages();
    state = messages;
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(Duration(seconds: 1), (_) async {
      final newMessages = await _apiService.getNewMessages();
      if (newMessages.isNotEmpty) {
        state = [...state, ...newMessages];
      }
    });
  }

  Future<bool> sendMessage(String text) async {
    // Nejprve přidáme zprávu do UI pro okamžitou odezvu
    final newMessage = Message(
      text: text,
      timestamp: DateTime.now(),
      isSentByMe: true,
    );
    state = [...state, newMessage];
    // Poté odešleme zprávu přes API
    final success = await _apiService.sendMessage(text);
    if (!success) {
      // Pokud se odeslání nezdařilo, odstraníme zprávu z UI
      state =
          state
              .where(
                (msg) =>
                    !(msg.text == text &&
                        msg.isSentByMe &&
                        msg.timestamp
                                .difference(newMessage.timestamp)
                                .inSeconds
                                .abs() <
                            2),
              )
              .toList();
    }
    return success;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

// API služba pro komunikaci s backendem
class ApiService {
  final String baseUrl;
  ApiService({this.baseUrl = 'http://localhost:8080/api'});

  Future<bool> sendMessage(String message) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  Future<List<Message>> getMessages() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/messages'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return (data['messages'] as List)
              .map(
                (msg) => Message(
                  text: msg['text'],
                  timestamp: DateTime.fromMillisecondsSinceEpoch(
                    (msg['timestamp'] * 1000).toInt(),
                  ),
                  isSentByMe: msg['isSentByMe'],
                ),
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }

  Future<List<Message>> getNewMessages() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/new-messages'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          // Získáváme pouze zprávy od druhého uživatele
          return (data['messages'] as List)
              .map(
                (msg) => Message(
                  text: msg['text'],
                  timestamp: DateTime.fromMillisecondsSinceEpoch(
                    (msg['timestamp'] * 1000).toInt(),
                  ),
                  isSentByMe: msg['isSentByMe'],
                ),
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching new messages: $e');
      return [];
    }
  }

  Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/status'))
          .timeout(Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendShutdownMessage() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': '==SHUTDOWN=='}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error sending shutdown message: $e');
      return false;
    }
  }
}

class TotallySecretApp extends ConsumerStatefulWidget {
  const TotallySecretApp({super.key});

  @override
  ConsumerState<TotallySecretApp> createState() => _TotallySecretAppState();
}

class _TotallySecretAppState extends ConsumerState<TotallySecretApp> {
  // Proměnné pro uložení rozlišení -- placeholder, později získávat z pythonu
  final int screenWidth = 2560; // Šířka obrazovky
  final int screenHeight = 1440; // Výška obrazovky
  final TextEditingController _textController = TextEditingController();
  Timer? _connectionTimer;
  // Proměnné pro backend inicializaci
  String _backendPath = '';
  String _scriptOutput = '';
  Process? pythonProcess;
  Process? configApiProcess; // Nová proměnná pro config API proces
  bool _isRunning = false;
  bool _isInitializing = true; // Indikuje, zda jsme ve fázi inicializace
  bool _connectionSuccessful = false; // Indikuje, zda bylo připojení úspěšné
  bool _isDarkTheme = true; // Indikuje, zda je použit tmavý motiv

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _setWindowSize();
      _startConfigApi(); // Spustíme config API při startu aplikace
    });
  }

  Future _startConfigApi() async {
    try {
      setState(() {
        _scriptOutput += 'Spouštím config API...\n';
      });

      // Najdi backend složku (zůstává, jak máš)
      final currentDir = Directory.current;
      List<String> possiblePaths = [
        '${currentDir.path}/backend',
        '${currentDir.path}/../backend',
        '/home/ryuseless/Git/Github/XPC-MMA/Project/TotallyLegitCalculator/backend',
      ];
      for (String path in possiblePaths) {
        final dir = Directory(path);
        if (dir.existsSync()) {
          _backendPath = path;
          break;
        }
      }
      if (_backendPath.isEmpty) {
        setState(() {
          _scriptOutput += 'Backend folder not found for config_api\n';
        });
        return;
      }

      // Spusť přímo binárku config_api
      final configApiPath = '$_backendPath/dist/config_api';
      configApiProcess = await Process.start(
        configApiPath,
        [],
        workingDirectory: '$_backendPath/dist',
      );

      configApiProcess!.stdout.transform(utf8.decoder).listen((data) {
        setState(() {
          _scriptOutput += '[config_api] $data';
        });
      });

      configApiProcess!.stderr.transform(utf8.decoder).listen((data) {
        setState(() {
          _scriptOutput += '[config_api ERROR] $data';
        });
      });

      // Počkej na start serveru (zkus 10s)
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(seconds: 1));
        try {
          final response = await http
              .get(Uri.parse('http://localhost:8090/api/config'))
              .timeout(const Duration(seconds: 1));
          if (response.statusCode == 200) {
            setState(() {
              _scriptOutput += 'Config API server je připraven.\n';
            });
            return;
          }
        } catch (_) {}
      }

      setState(() {
        _scriptOutput += 'Config API server nebyl nalezen po 10s.\n';
      });
    } catch (e) {
      setState(() {
        _scriptOutput += 'Chyba při spouštění config API: $e\n';
      });
    }
  }

  Future<void> _setWindowSize() async {
    // Nastavení velikosti okna na rozlišení displeje
    await windowManager.setSize(
      Size(screenWidth.toDouble(), screenHeight.toDouble()),
    );
  }

  Future<void> _resizeToOriginal() async {
    await windowManager.setSize(const Size(400, 800));
  }

  void _findBackendFolder() {
    try {
      // Zjištění aktuálního pracovního adresáře
      final currentDir = Directory.current;
      print('Aktuální pracovní adresář: ${currentDir.path}');
      // Zkusíme najít backend složku různými způsoby
      List<String> possiblePaths = [
        '${currentDir.path}/backend',
        '${currentDir.path}/../backend',
        '/home/ryuseless/Git/Github/XPC-MMA/Project/TotallyLegitCalculator/backend',
      ];
      for (String path in possiblePaths) {
        final dir = Directory(path);
        if (dir.existsSync()) {
          _backendPath = path;
          setState(() {});
          _runBackendScript();
          break;
        }
      }
      // Pokud jsme nenašli backend složku, zkusíme ji najít pomocí příkazu find
      if (_backendPath.isEmpty) {
        _findBackendUsingCommand();
      }
    } catch (e) {
      setState(() {
        _scriptOutput += 'Error finding backend folder: $e\n';
      });
    }
  }

  Future<void> _findBackendUsingCommand() async {
    try {
      final result = await Process.run('find', [
        '/home',
        '-name',
        'TotallyLegitCalculator',
        '-type',
        'd',
      ]);
      if (result.stdout.toString().isNotEmpty) {
        final projectPath = result.stdout.toString().trim().split('\n').first;
        _backendPath = '$projectPath/backend';
        setState(() {});
        _runBackendScript();
      } else {
        setState(() {
          _scriptOutput += 'Backend folder not found using find command\n';
        });
      }
    } catch (e) {
      setState(() {
        _scriptOutput += 'Error using find command: $e\n';
      });
    }
  }

  Future _runBackendScript() async {
    try {
      setState(() {
        _scriptOutput +=
            '=== Starting peer connection (Waiting for other peer to connect) ===\n';
        _isRunning = true;
      });
      final appPath = '$_backendPath/dist/app';
      pythonProcess = await Process.start(
        appPath,
        [],
        workingDirectory: '$_backendPath/dist',
      );
      pythonProcess!.stdout.transform(utf8.decoder).listen((data) {
        setState(() {
          _scriptOutput += 'Output: $data\n';
        });
      });
      pythonProcess!.stderr.transform(utf8.decoder).listen((data) {
        setState(() {
          _scriptOutput += 'API INFO: $data\n';
        });
      });
      await Future.delayed(Duration(seconds: 2));
      _startConnectionCheck();
    } catch (e) {
      setState(() {
        _scriptOutput += 'Error running app: $e\n';
        _isRunning = false;
      });
    }
  }

  void _startConnectionCheck() {
    _connectionTimer = Timer.periodic(Duration(seconds: 1), (_) async {
      try {
        final response = await http
            .get(Uri.parse('http://localhost:8080/api/status'))
            .timeout(Duration(seconds: 2));
        if (response.statusCode == 200) {
          // API je připraveno, můžeme přejít do chat režimu
          _connectionTimer?.cancel();
          setState(() {
            _connectionSuccessful = true;
            _scriptOutput += 'Backend API is running and ready!\n';
          });
        }
      } catch (e) {
        // API ještě není připraveno, pokračujeme v kontrole
      }
    });
    // Nastavíme timeout pro případ, že se API nepodaří spustit
    Future.delayed(Duration(seconds: 30), () {
      if (!_connectionSuccessful) {
        _connectionTimer?.cancel();
        setState(() {
          _scriptOutput +=
              'Backend initialization timeout. Please check the logs.\n';
        });
      }
    });
  }

  void _startChatConnectionCheck() {
    _connectionTimer = Timer.periodic(Duration(seconds: 3), (_) async {
      final isConnected = await ref.read(apiServiceProvider).checkConnection();
      if (!isConnected) {
        _connectionTimer?.cancel();
        _stopPythonBackend();
        await _resizeToOriginal();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CalculatorScreenDesktop(),
          ),
        );
      }
    });
  }

  void _stopPythonBackend() {
    if (pythonProcess != null) {
      print('Ukončuji Python backend');
      pythonProcess!.kill();
      pythonProcess = null;
      _isRunning = false;
    }

    if (configApiProcess != null) {
      print('Ukončuji Config API');
      configApiProcess!.kill();
      configApiProcess = null;
    }
  }

  Future<void> _sendShutdownAndGoBack() async {
    try {
      // Odeslání zprávy ==SHUTDOWN== před návratem do coverApp
      await ref.read(apiServiceProvider).sendShutdownMessage();
      // Krátké čekání, aby se zpráva stihla odeslat
      await Future.delayed(Duration(milliseconds: 500));
      // Ukončení Python backendu
      _stopPythonBackend();
    } catch (e) {
      print('Error sending shutdown message: $e');
    } finally {
      await _resizeToOriginal();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const CalculatorScreenDesktop(),
        ),
      );
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim(); // Oříznout text
    if (text.isEmpty) return; // Kontrola prázdného textu
    ref.read(messagesProvider.notifier).sendMessage(text).then((success) {
      if (success) {
        _textController.clear(); // Vyčistit textové pole po odeslání
      } else {
        // Zobrazit chybovou hlášku
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Nepodařilo se odeslat zprávu')));
      }
    });
  }

  void _openSettings() {
    Navigator.pushNamed(context, '/settings');
  }

  void _toggleTheme() {
    setState(() {
      _isDarkTheme = !_isDarkTheme;
    });
  }

  void _proceedToChat() {
    setState(() {
      _isInitializing = false;
    });
    _startChatConnectionCheck();
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _stopPythonBackend();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pokud jsme ve fázi inicializace, zobrazíme obrazovku s konzolí
    if (_isInitializing) {
      return Scaffold(
        body: Column(
          children: [
            // Konzole nahoře
            Expanded(
              child: Container(
                padding: EdgeInsets.all(16),
                color: Colors.black,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Console',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          border: Border.all(color: Colors.green, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            _scriptOutput.isEmpty
                                ? 'Waiting for connection...'
                                : _scriptOutput,
                            style: TextStyle(
                              color: Colors.green,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_connectionSuccessful)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Center(
                          child: ElevatedButton(
                            onPressed: _proceedToChat,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Success! Proceed to Chat',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Tmavá lišta s tlačítky dole
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.refresh,
                    label: 'Connect',
                    onPressed: _isRunning ? null : _findBackendFolder,
                    color: Colors.blue,
                  ),
                  _buildActionButton(
                    icon: Icons.settings,
                    label: 'Settings',
                    onPressed: _openSettings,
                    color: Colors.orange,
                  ),
                  _buildActionButton(
                    icon: Icons.exit_to_app,
                    label: 'Exit',
                    onPressed: () async {
                      _stopPythonBackend();
                      await _resizeToOriginal();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CalculatorScreenDesktop(),
                        ),
                      );
                    },
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Pokud jsme ve fázi chatu, zobrazíme chat obrazovku
    final messages = ref.watch(messagesProvider);
    // Seřazení zpráv podle času (nejnovější nahoře)
    final sortedMessages = List<Message>.from(messages)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      body: Column(
        children: <Widget>[
          // Horní lišta
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _isDarkTheme ? Colors.grey[850] : Colors.blue,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Secure Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isDarkTheme ? Icons.light_mode : Icons.dark_mode,
                        color: Colors.white,
                      ),
                      tooltip: 'Toggle Theme',
                      onPressed: _toggleTheme,
                    ),
                    IconButton(
                      icon: Icon(Icons.settings, color: Colors.white),
                      tooltip: 'Settings',
                      onPressed: _openSettings,
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _sendShutdownAndGoBack,
                      icon: Icon(Icons.exit_to_app),
                      label: Text('Exit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Prostřední šedý obdélník
          Expanded(
            flex: 10,
            child: Container(
              width: double.infinity,
              color: _isDarkTheme ? Colors.grey[900] : Colors.grey[300],
              child: ListView.builder(
                reverse: true,
                itemCount: sortedMessages.length,
                itemBuilder: (context, index) {
                  final message = sortedMessages[index];
                  return Align(
                    alignment:
                        message.isSentByMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            message.isSentByMe
                                ? (_isDarkTheme
                                    ? Colors.blue[700]
                                    : Colors.blue[400])
                                : (_isDarkTheme
                                    ? Colors.grey[700]
                                    : Colors.grey[400]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            message.isSentByMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.text,
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  _isDarkTheme ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            "${message.timestamp.hour}:${message.timestamp.minute}",
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  _isDarkTheme
                                      ? Colors.white70
                                      : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Spodní černý obdélník
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: _isDarkTheme ? Colors.black : Colors.grey[200],
            child: Row(
              children: [
                // Ikona pro vkládání fotek
                IconButton(
                  icon: Icon(
                    Icons.add_photo_alternate,
                    color: _isDarkTheme ? Colors.white : Colors.black87,
                    size: 28,
                  ),
                  onPressed: () {}, // Zatím bez funkce
                ),
                // Textový vstup
                Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 8),
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: _isDarkTheme ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color:
                            _isDarkTheme
                                ? Colors.grey[600]!
                                : Colors.grey[300]!,
                      ),
                    ),
                    child: TextField(
                      controller: _textController,
                      style: TextStyle(
                        color: _isDarkTheme ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Type a message...",
                        hintStyle: TextStyle(
                          color:
                              _isDarkTheme
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                        ),
                      ),
                      onSubmitted: (text) {
                        if (text.trim().isNotEmpty) {
                          _sendMessage();
                        }
                      },
                    ),
                  ),
                ),
                // Ikona pro emotikony
                IconButton(
                  icon: Icon(
                    Icons.emoji_emotions,
                    color: _isDarkTheme ? Colors.white : Colors.black87,
                    size: 28,
                  ),
                  onPressed: () {}, // Zatím bez funkce
                ),
                // Ikona pro odeslání zprávy
                IconButton(
                  icon: Icon(Icons.send, color: Colors.blue, size: 28),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class Message {
  final String text;
  final DateTime timestamp;
  final bool isSentByMe;

  Message({
    required this.text,
    required this.timestamp,
    required this.isSentByMe,
  });
}
