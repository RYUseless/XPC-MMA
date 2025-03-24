import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UpdatePage extends StatefulWidget {
  final int noteId;
  final VoidCallback onNoteUpdated; // Callback pro reload poznámek

  const UpdatePage({
    super.key,
    required this.noteId,
    required this.onNoteUpdated,
  });

  @override
  _UpdatePageState createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  final TextEditingController _contentController = TextEditingController();

  // Funkce pro načtení poznámky
  Future<void> _loadNote() async {
    final String apiUrl = 'http://127.0.0.1:8000/notes/${widget.noteId}/';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        setState(() {
          _contentController.text = jsonDecode(response.body)['body'];
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Chyba při načítání poznámky.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba při komunikaci s backendem: $e')),
      );
    }
  }

  // Funkce pro odeslání aktualizace poznámky
  Future<void> _updateNote() async {
    final String apiUrl =
        'http://127.0.0.1:8000/notes/update/${widget.noteId}/';

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "body": _contentController.text, // Posíláme pouze body
        }),
      );

      if (response.statusCode == 200) {
        widget.onNoteUpdated(); // Zavoláme callback pro reload
        Navigator.pop(context); // Vrátíme se zpět na předchozí stránku
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Poznámka byla aktualizována')));
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
  void initState() {
    super.initState();
    _loadNote(); // Načteme poznámku při inicializaci
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upravit poznámku')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // TextField pro editaci poznámky
            TextField(
              controller: _contentController,
              decoration: InputDecoration(labelText: 'Obsah poznámky'),
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              onTap: () {
                // Možnost upravit při kliknutí na textový pole
                setState(() {
                  // Tady můžeš přidat další logiku pro editaci
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(onPressed: _updateNote, child: Text('Upravit')),
          ],
        ),
      ),
    );
  }
}
