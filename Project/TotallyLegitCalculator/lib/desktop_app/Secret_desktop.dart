import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'Calculator_desktop.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TotallySecretApp extends ConsumerStatefulWidget {
  const TotallySecretApp({Key? key}) : super(key: key);

  @override
  ConsumerState<TotallySecretApp> createState() => _TotallySecretAppState();
}

class _TotallySecretAppState extends ConsumerState<TotallySecretApp> {
  // Proměnné pro uložení rozlišení -- placeholder, později získávat z pythonu
  final int screenWidth = 2560; // Šířka obrazovky
  final int screenHeight = 1440; // Výška obrazovky

  final TextEditingController _textController = TextEditingController();
  List<Message> _sentMessages = []; // Seznam odeslaných zpráv
  List<Message> _receivedMessages = []; // Seznam přijatých zpráv

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _setWindowSize();
    });
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

  void _sendMessage() {
    setState(() {
      _sentMessages.add(
        Message(
          text: _textController.text,
          timestamp: DateTime.now(),
          isSentByMe: true,
        ),
      );
      _textController.clear();
    });
  }

  // not used now:
  void _receiveMessage(String text) {
    setState(() {
      _receivedMessages.add(
        Message(text: text, timestamp: DateTime.now(), isSentByMe: false),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          // Horní modrý obdélník
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              color: Colors.blue,
              child: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    await _resizeToOriginal();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CalculatorScreenDesktop(),
                      ),
                    );
                  },
                  child: const Text('Go back to coverApp'),
                ),
              ),
            ),
          ),
          // Prostřední šedý obdélník
          Expanded(
            flex: 10,
            child: Container(
              width: double.infinity,
              color: Colors.grey[300],
              child: ListView.builder(
                reverse: true,
                itemCount: _sentMessages.length + _receivedMessages.length,
                itemBuilder: (context, index) {
                  final allMessages = [..._receivedMessages, ..._sentMessages];
                  final message = allMessages.reversed.toList()[index];

                  return Align(
                    alignment:
                        message.isSentByMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: message.isSentByMe ? Colors.red : Colors.grey,
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
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            "${message.timestamp.hour}:${message.timestamp.minute}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
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
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: Row(
                children: [
                  // Ikona pro vkládání fotek
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "+", // Zatím jen jako design
                      style: const TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  ),
                  // Textový vstup
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "Napište zprávu",
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      onSubmitted: (text) {
                        _sendMessage();
                      },
                    ),
                  ),
                  // Ikona pro emotikony
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "👳‍♂️✈🏢🏢", // Zatím jen jako design
                      style: const TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  ),
                  // Ikona pro odeslání zprávy
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
