import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ScreenTwo extends StatelessWidget {
  final String text;

  const ScreenTwo({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Second Screen')),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          Fluttertoast.showToast(
            msg: 'Current Page: 2',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Received text: $text'),
              TextField(
                decoration: const InputDecoration(labelText: 'New Text Box'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
