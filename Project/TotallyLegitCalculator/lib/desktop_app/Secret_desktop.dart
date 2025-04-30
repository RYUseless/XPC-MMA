import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'Calculator_desktop.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;

// Provider pro API službu
final apiServiceProvider = Provider((ref) => ApiService());

// Provider pro zprávy
final messagesProvider = StateNotifierProvider<MessagesNotifier, List<Message>>(
  (ref) {
    final apiService = ref.watch(apiServiceProvider);
    return MessagesNotifier(apiService);
  },
);

class MessagesNotifier extends StateNotifier<List<Message>> {
  final ApiService _apiService;
  Timer? _refreshTimer;

  MessagesNotifier(this._apiService) : super([]) {
    _loadInitialMessages();
    _startRefreshTimer();
  }

  Future _loadInitialMessages() async {
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

class TotallySecretApp extends ConsumerStatefulWidget {
  const TotallySecretApp({super.key});

  @override
  ConsumerState<TotallySecretApp> createState() => _TotallySecretAppState();
}

class _TotallySecretAppState extends ConsumerState<TotallySecretApp> {
  final int screenWidth = 1920;
  final int screenHeight = 1080;
  final TextEditingController _textController = TextEditingController();
  Timer? _connectionTimer;
  String _backendPath = '';
  String _scriptOutput = '';
  Process? pythonProcess;
  Process? configApiProcess;
  bool _isRunning = false;
  bool _isInitializing = true;
  bool _connectionSuccessful = false;
  bool _isDarkTheme = true;
  bool _emojiShowing = false;
  final FocusNode _focusNode = FocusNode();

  final ScrollController _scrollController = ScrollController();
  // scroll constant

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _setWindowSize();
      _startConfigApi();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    FocusManager.instance.addListener(() {
      if (FocusManager.instance.primaryFocus?.context?.widget
          is! EditableText) {
        _focusNode.requestFocus();
      }
    });
  }

  Future _startConfigApi() async {
    try {
      setState(() {
        _scriptOutput += 'Spouštím config API...\n';
      });
      final currentDir = Directory.current;
      List<String> possiblePaths = [
        '${currentDir.path}/backend',
        '${currentDir.path}/../backend',
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

  Future _setWindowSize() async {
    await windowManager.setSize(
      Size(screenWidth.toDouble(), screenHeight.toDouble()),
    );
  }

  Future _resizeToOriginal() async {
    await windowManager.setSize(const Size(400, 800));
  }

  void _findBackendFolder() {
    try {
      final currentDir = Directory.current;
      print('Aktuální pracovní adresář: ${currentDir.path}');
      List<String> possiblePaths = [
        '${currentDir.path}/backend',
        '${currentDir.path}/../backend',
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
      if (_backendPath.isEmpty) {
        setState(() {
          _scriptOutput += 'Backend folder not found!\n';
        });
      }
    } catch (e) {
      setState(() {
        _scriptOutput += 'Error finding backend folder: $e\n';
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
      await Future.delayed(Duration(seconds: 2));
      _startConnectionCheck();
    } catch (e) {
      setState(() {
        _scriptOutput += ' !!! Error running app: $e !!!!\n';
        _isRunning = false;
      });
    }
  }

  void _startConnectionCheck() {
    _connectionTimer = Timer.periodic(Duration(seconds: 1), (_) async {
      try {
        final response = await http
            .get(Uri.parse('http://localhost:8080/api/status'))
            .timeout(Duration(seconds: 1));
        if (response.statusCode == 200) {
          _connectionTimer?.cancel();
          setState(() {
            _connectionSuccessful = true;
            _scriptOutput += '=== PEER CONNECTED SUCESFULLY ===\n';
          });
        }
      } catch (e) {}
    });
    Future.delayed(Duration(seconds: 600), () {
      if (!_connectionSuccessful) {
        _connectionTimer?.cancel();
        setState(() {
          _scriptOutput +=
              '=== Backend initialization timeout. There is no peer avaiable ===.\n';
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

  Future _sendShutdownAndGoBack() async {
    try {
      await ref.read(apiServiceProvider).sendShutdownMessage();
      await Future.delayed(Duration(milliseconds: 500));
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    ref.read(messagesProvider.notifier).sendMessage(text).then((success) {
      if (success) {
        _textController.clear();
        _scrollToBottom(); // scroll dolu -- pokus issues -- pryc
      } else {
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
    _scrollController.dispose(); // scroll release, kdyby nahodou issues
    _focusNode.dispose();
    super.dispose();
  }

  // EMOJI FONT
  String? _getEmojiFontFamily() {
    if (foundation.defaultTargetPlatform == TargetPlatform.windows) {
      return 'Segoe UI Emoji';
    } else if (foundation.defaultTargetPlatform == TargetPlatform.linux) {
      return 'Noto Color Emoji';
    } else if (foundation.defaultTargetPlatform == TargetPlatform.macOS) {
      return 'Apple Color Emoji';
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        body: Column(
          children: [
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

    final messages = ref.watch(messagesProvider);
    final sortedMessages = List.from(messages)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // --- scroll na konec pri nove zprave  ---
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      body: Column(
        children: [
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
          Expanded(
            flex: 10,
            child: Container(
              width: double.infinity,
              color: _isDarkTheme ? Colors.grey[900] : Colors.grey[300],
              child: ListView.builder(
                controller: _scrollController,
                itemCount: sortedMessages.length,
                itemBuilder: (context, index) {
                  final message = sortedMessages[index];
                  final emojiOnly = RegExp(
                    r'^(\p{Emoji_Presentation}|\p{Emoji}\uFE0F|\p{Emoji_Modifier_Base}|\p{Emoji_Component}|\s)+$',
                    unicode: true,
                  ).hasMatch(message.text);
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
                            emojiOnly
                                ? Colors.transparent
                                : (message.isSentByMe
                                    ? (_isDarkTheme
                                        ? Colors.blue[700]
                                        : Colors.blue[400])
                                    : (_isDarkTheme
                                        ? Colors.grey[700]
                                        : Colors.grey[400])),
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
                              fontSize: emojiOnly ? 36 : 16,
                              color:
                                  _isDarkTheme ? Colors.white : Colors.black87,
                              fontFamily:
                                  emojiOnly ? _getEmojiFontFamily() : null,
                            ),
                          ),
                          Text(
                            "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
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
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: _isDarkTheme ? Colors.black : Colors.grey[200],
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.add_photo_alternate,
                        color: _isDarkTheme ? Colors.white : Colors.black87,
                        size: 28,
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
                          focusNode: _focusNode,
                          autofocus: true,
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
                          onTap: () {
                            setState(() {
                              _emojiShowing = false;
                            });
                          },
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.emoji_emotions,
                        color: _isDarkTheme ? Colors.white : Colors.black87,
                        size: 28,
                      ),
                      onPressed: () {
                        if (_emojiShowing) {
                          _focusNode.requestFocus();
                        } else {
                          _focusNode.unfocus();
                        }
                        setState(() {
                          _emojiShowing = !_emojiShowing;
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.send, color: Colors.blue, size: 28),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
                Offstage(
                  offstage: !_emojiShowing,
                  child: SizedBox(
                    height: 256,
                    child: EmojiPicker(
                      textEditingController: _textController,
                      onEmojiSelected: (category, emoji) {
                        if (_textController.text.trim().isEmpty) {
                          _textController.text = emoji.emoji;
                          _sendMessage();
                          _textController.clear();
                        }
                      },
                      config: Config(
                        height: 256,
                        emojiViewConfig: EmojiViewConfig(
                          emojiSizeMax:
                              28 *
                              (foundation.defaultTargetPlatform ==
                                      TargetPlatform.iOS
                                  ? 1.2
                                  : 1.0),
                        ),
                        skinToneConfig: const SkinToneConfig(),
                        categoryViewConfig: const CategoryViewConfig(),
                        bottomActionBarConfig: const BottomActionBarConfig(),
                        searchViewConfig: const SearchViewConfig(),
                        checkPlatformCompatibility: true,
                      ),
                    ),
                  ),
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
