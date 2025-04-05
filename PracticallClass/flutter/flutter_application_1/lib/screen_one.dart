import 'package:flutter/material.dart';
import 'screen_two.dart';

class ScreenOne extends StatefulWidget {
  const ScreenOne({super.key});

  @override
  _ScreenOneState createState() => _ScreenOneState();
}

class _ScreenOneState extends State<ScreenOne> {
  TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('First Screen')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Enter some text'),
            ),
            ElevatedButton(
              onPressed: () {
                String text = controller.text;
                controller.clear();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScreenTwo(text: text),
                  ),
                );
              },
              child: const Text('Go to Second Screen'),
            ),
          ],
        ),
      ),
    );
  }
}
