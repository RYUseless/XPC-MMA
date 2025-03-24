import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreatePage extends StatefulWidget {
  final VoidCallback onNoteCreated; // Callback pro reload poznámek

  const CreatePage({super.key, required this.onNoteCreated});

  @override
  _CreatePageState createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  final TextEditingController _contentController = TextEditingController();

  // Funkce pro odeslání nové poznámky
  Future<void> _createNote() async {
    final String apiUrl =
        'http://127.0.0.1:8000/notes/create/'; // URL pro vytvoření poznámky

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "body": _contentController.text, // Posíláme pouze body
        }),
      );

      if (response.statusCode == 201) {
        widget.onNoteCreated(); // Zavoláme callback pro reload
        Navigator.pop(context); // Vrátíme se zpět na předchozí stránku
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Poznámka byla vytvořena')));
      } else {
        final errorMessage =
            jsonDecode(response.body)['error'] ?? 'Neznámá chyba';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Chyba: $errorMessage')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba při komunikaci s backendem: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Vytvořit poznámku')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              decoration: InputDecoration(labelText: 'Obsah poznámky'),
              maxLines: 5,
            ),
            SizedBox(height: 20),
            ElevatedButton(onPressed: _createNote, child: Text('Uložit')),
          ],
        ),
      ),
    );
  }
}
