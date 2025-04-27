import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'Calculator_mobile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// Provider pro API službu
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

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
    final newMessage = Message(
      text: text,
      timestamp: DateTime.now(),
      isSentByMe: true,
    );
    state = [...state, newMessage];
    final success = await _apiService.sendMessage(text);
    if (!success) {
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

class TotallySecretMobileApp extends ConsumerStatefulWidget {
  const TotallySecretMobileApp({super.key});

  @override
  ConsumerState<TotallySecretMobileApp> createState() =>
      _TotallySecretAppState();
}

class _TotallySecretAppState extends ConsumerState<TotallySecretMobileApp> {
  final TextEditingController _textController = TextEditingController();
  Timer? _connectionTimer;
  String _scriptOutput = '';
  Process? pythonProcess;
  Process? configApiProcess;
  bool _isRunning = false;
  bool _isInitializing = true;
  bool _connectionSuccessful = false;
  bool _isDarkTheme = true;
  String _backendPath = '';
  String _tempBackendPath = '';

  @override
  void initState() {
    super.initState();
    _initializeBackend();
  }

  // Inicializace backendu - extrakce assetů a příprava prostředí
  Future<void> _initializeBackend() async {
    setState(() {
      _scriptOutput += 'Inicializuji backend...\n';
    });

    try {
      // Získání cesty k dočasnému adresáři
      final tempDir = await getTemporaryDirectory();
      _tempBackendPath = '${tempDir.path}/backend';

      setState(() {
        _scriptOutput += 'Dočasná cesta pro backend: $_tempBackendPath\n';
      });

      // Vytvoření dočasného adresáře pro backend
      final backendDir = Directory(_tempBackendPath);
      if (await backendDir.exists()) {
        await backendDir.delete(recursive: true);
      }
      await backendDir.create(recursive: true);

      // Výpis dostupných assetů
      setState(() {
        _scriptOutput += 'Kontroluji dostupné assety...\n';
      });

      // Kontrola, zda jsou skripty dostupné jako assety
      try {
        await rootBundle.loadString('backend/_start_config_android.sh');
        setState(() {
          _scriptOutput +=
              'Skript _start_config_android.sh nalezen v assets.\n';
        });
      } catch (e) {
        setState(() {
          _scriptOutput +=
              'Skript _start_config_android.sh není v assets: $e\n';
        });
      }

      try {
        await rootBundle.loadString('backend/_start_app.sh');
        setState(() {
          _scriptOutput += 'Skript _start_app.sh nalezen v assets.\n';
        });
      } catch (e) {
        setState(() {
          _scriptOutput += 'Skript _start_app.sh není v assets: $e\n';
        });
      }

      // Extrakce skriptů z assetů do dočasného adresáře
      try {
        final configScriptContent = await rootBundle.loadString(
          'backend/_start_config_android.sh',
        );
        final configScriptFile = File(
          '$_tempBackendPath/_start_config_android.sh',
        );
        await configScriptFile.writeAsString(configScriptContent);
        await Process.run('chmod', ['+x', configScriptFile.path]);

        setState(() {
          _scriptOutput +=
              'Skript _start_config_android.sh extrahován a nastaven jako spustitelný.\n';
        });
      } catch (e) {
        setState(() {
          _scriptOutput += 'Chyba při extrakci _start_config_android.sh: $e\n';
        });
      }

      try {
        final appScriptContent = await rootBundle.loadString(
          'backend/_start_app.sh',
        );
        final appScriptFile = File('$_tempBackendPath/_start_app.sh');
        await appScriptFile.writeAsString(appScriptContent);
        await Process.run('chmod', ['+x', appScriptFile.path]);

        setState(() {
          _scriptOutput +=
              'Skript _start_app.sh extrahován a nastaven jako spustitelný.\n';
        });
      } catch (e) {
        setState(() {
          _scriptOutput += 'Chyba při extrakci _start_app.sh: $e\n';
        });
      }

      // Extrakce dalších potřebných souborů
      try {
        final activateVenvContent = await rootBundle.loadString(
          'backend/_activate_venv.sh',
        );
        final activateVenvFile = File('$_tempBackendPath/_activate_venv.sh');
        await activateVenvFile.writeAsString(activateVenvContent);
        await Process.run('chmod', ['+x', activateVenvFile.path]);

        setState(() {
          _scriptOutput +=
              'Skript _activate_venv.sh extrahován a nastaven jako spustitelný.\n';
        });
      } catch (e) {
        setState(() {
          _scriptOutput += 'Chyba při extrakci _activate_venv.sh: $e\n';
        });
      }

      try {
        final requirementsContent = await rootBundle.loadString(
          'backend/requirements.txt',
        );
        final requirementsFile = File('$_tempBackendPath/requirements.txt');
        await requirementsFile.writeAsString(requirementsContent);

        setState(() {
          _scriptOutput += 'Soubor requirements.txt extrahován.\n';
        });
      } catch (e) {
        setState(() {
          _scriptOutput += 'Chyba při extrakci requirements.txt: $e\n';
        });
      }

      // Vytvoření src adresáře
      final srcDir = Directory('$_tempBackendPath/src');
      await srcDir.create();

      // Extrakce Python souborů
      try {
        final configApiContent = await rootBundle.loadString(
          'backend/src/config_api.py',
        );
        final configApiFile = File('$_tempBackendPath/src/config_api.py');
        await configApiFile.writeAsString(configApiContent);

        setState(() {
          _scriptOutput += 'Soubor config_api.py extrahován.\n';
        });
      } catch (e) {
        setState(() {
          _scriptOutput += 'Chyba při extrakci config_api.py: $e\n';
        });
      }

      try {
        final appPyContent = await rootBundle.loadString('backend/app.py');
        final appPyFile = File('$_tempBackendPath/app.py');
        await appPyFile.writeAsString(appPyContent);

        setState(() {
          _scriptOutput += 'Soubor app.py extrahován.\n';
        });
      } catch (e) {
        setState(() {
          _scriptOutput += 'Chyba při extrakci app.py: $e\n';
        });
      }

      // Nastavení cesty k backendu
      _backendPath = _tempBackendPath;

      setState(() {
        _scriptOutput += 'Backend inicializován v: $_backendPath\n';
      });

      // Spuštění config API
      _startConfigApi();
    } catch (e) {
      setState(() {
        _scriptOutput += 'Chyba při inicializaci backendu: $e\n';
      });
    }
  }

  // Výpis obsahu adresáře
  Future<void> _listDirectoryContents(String path) async {
    try {
      final directory = Directory(path);
      if (await directory.exists()) {
        setState(() {
          _scriptOutput += '\n===== OBSAH ADRESÁŘE: $path =====\n';
        });

        final entities = await directory.list().toList();

        // Nejprve vypíšeme adresáře
        final dirs = entities.where((e) => e is Directory).toList();
        if (dirs.isNotEmpty) {
          setState(() {
            _scriptOutput += '--- ADRESÁŘE ---\n';
            for (var dir in dirs) {
              _scriptOutput += '📁 ${dir.path.split('/').last}/\n';
            }
          });
        }

        // Potom vypíšeme soubory
        final files = entities.where((e) => e is File).toList();
        if (files.isNotEmpty) {
          setState(() {
            _scriptOutput += '--- SOUBORY ---\n';
            for (var file in files) {
              _scriptOutput += '📄 ${file.path.split('/').last}\n';
            }
          });
        }

        if (entities.isEmpty) {
          setState(() {
            _scriptOutput += 'Adresář je prázdný.\n';
          });
        }

        setState(() {
          _scriptOutput += '=============================\n';
        });
      } else {
        setState(() {
          _scriptOutput += 'Adresář $path neexistuje.\n';
        });
      }
    } catch (e) {
      setState(() {
        _scriptOutput += 'Chyba při výpisu obsahu adresáře: $e\n';
      });
    }
  }

  Future<void> _startConfigApi() async {
    try {
      setState(() {
        _scriptOutput += 'Spouštím config API...\n';
      });

      if (_backendPath.isEmpty) {
        setState(() {
          _scriptOutput +=
              'Backend path není nastaven. Nelze spustit config API.\n';
        });
        return;
      }

      // Kontrola, zda skript existuje
      final scriptFile = File('$_backendPath/_start_config_android.sh');
      if (!await scriptFile.exists()) {
        setState(() {
          _scriptOutput += 'Skript _start_config_android.sh nenalezen.\n';
        });
        return;
      }

      // Výpis obsahu adresáře před spuštěním
      await _listDirectoryContents(_backendPath);

      configApiProcess = await Process.start(
        'bash',
        ['$_backendPath/_start_config_android.sh'],
        workingDirectory: _backendPath,
        runInShell: true,
      );

      configApiProcess!.stdout.transform(utf8.decoder).listen((data) {
        setState(() {
          _scriptOutput += data;
        });
      });

      configApiProcess!.stderr.transform(utf8.decoder).listen((data) {
        setState(() {
          _scriptOutput += 'Error: $data';
        });
      });

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

  Future<void> _runBackendScript() async {
    try {
      setState(() {
        _scriptOutput += 'Starting Peer connection \n';
        _isRunning = true;
      });

      if (_backendPath.isEmpty) {
        setState(() {
          _scriptOutput +=
              'Backend path není nastaven. Nelze spustit peer connection.\n';
          _isRunning = false;
        });
        return;
      }

      // Kontrola, zda skript existuje
      final scriptFile = File('$_backendPath/_start_app.sh');
      if (!await scriptFile.exists()) {
        setState(() {
          _scriptOutput += 'Skript _start_app.sh nenalezen.\n';
          _isRunning = false;
        });
        return;
      }

      pythonProcess = await Process.start('bash', [
        '$_backendPath/_start_app.sh',
      ], workingDirectory: _backendPath);

      pythonProcess!.stdout.transform(utf8.decoder).listen((data) {
        setState(() {
          _scriptOutput += 'Output: $data\n';
        });
      });

      pythonProcess!.stderr.transform(utf8.decoder).listen((data) {
        setState(() {
          _scriptOutput += 'Error: $data\n';
        });
      });

      await Future.delayed(Duration(seconds: 2));
      _startConnectionCheck();
    } catch (e) {
      setState(() {
        _scriptOutput += 'Error running script: $e\n';
        _isRunning = false;
      });
    }
  }

  void _findBackendFolder() {
    if (_backendPath.isNotEmpty) {
      _runBackendScript();
    } else {
      setState(() {
        _scriptOutput += 'Backend path is not set.\n';
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
          _connectionTimer?.cancel();
          setState(() {
            _connectionSuccessful = true;
            _scriptOutput += 'Backend API is running and ready!\n';
          });
        }
      } catch (e) {
        // API ještě není připraveno
      }
    });

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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Calculatorscreen()),
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
      await ref.read(apiServiceProvider).sendShutdownMessage();
      await Future.delayed(Duration(milliseconds: 500));
      _stopPythonBackend();
    } catch (e) {
      print('Error sending shutdown message: $e');
    } finally {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Calculatorscreen()),
      );
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    ref.read(messagesProvider.notifier).sendMessage(text).then((success) {
      if (success) {
        _textController.clear();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Nepodařilo se odeslat zprávu')));
      }
    });
  }

  void _openSettings() {
    Navigator.pushNamed(context, '/settings_mobile');
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
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Connection Console'),
          backgroundColor: Colors.black,
        ),
        body: Column(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.all(16),
                color: Colors.black,
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
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _proceedToChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text('Proceed to Chat'),
                ),
              ),
            Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.grey[850],
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.refresh),
                          label: Text('Connect'),
                          onPressed: _isRunning ? null : _findBackendFolder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.settings),
                          label: Text('Settings'),
                          onPressed: _openSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: Icon(Icons.exit_to_app),
                    label: Text('Exit'),
                    onPressed: () {
                      _stopPythonBackend();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Calculatorscreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final messages = ref.watch(messagesProvider);
    final sortedMessages = List<Message>.from(messages)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      appBar: AppBar(
        title: Text('Secure Chat'),
        backgroundColor: _isDarkTheme ? Colors.grey[850] : Colors.blue,
        actions: [
          IconButton(
            icon: Icon(_isDarkTheme ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleTheme,
          ),
          IconButton(icon: Icon(Icons.settings), onPressed: _openSettings),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
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
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            message.isSentByMe
                                ? (_isDarkTheme
                                    ? Colors.blue[700]
                                    : Colors.blue[400])
                                : (_isDarkTheme
                                    ? Colors.grey[700]
                                    : Colors.grey[400]),
                        borderRadius: BorderRadius.circular(16),
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
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: _isDarkTheme ? Colors.black : Colors.grey[200],
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.add_photo_alternate,
                    color: _isDarkTheme ? Colors.white : Colors.black87,
                  ),
                  onPressed: () {},
                ),
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
                IconButton(
                  icon: Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        child: Icon(Icons.exit_to_app),
        onPressed: _sendShutdownAndGoBack,
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
