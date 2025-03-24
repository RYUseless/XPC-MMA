import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NoteDetailPage extends StatefulWidget {
  final int noteId;

  // Konstruktor pro předání ID poznámky
  const NoteDetailPage({super.key, required this.noteId});

  @override
  _NoteDetailPageState createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  dynamic _note;

  // Funkce pro získání detailu poznámky z backendu
  Future<void> _fetchNoteDetail() async {
    final String apiUrl = 'http://127.0.0.1:8000/notes/${widget.noteId}/';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        setState(() {
          _note = jsonDecode(response.body); // Uložíme detail poznámky
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při načítání detailu poznámky.')),
        );
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
    _fetchNoteDetail(); // Načteme detail poznámky při inicializaci
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detaily poznámky')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child:
            _note == null
                ? Center(child: CircularProgressIndicator())
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titulek
                    Text(
                      'Poznámka ID: ${_note['id']}',
                      style:
                          Theme.of(
                            context,
                          ).textTheme.bodyLarge, // bodyLarge místo bodyText1
                    ),
                    SizedBox(height: 8),
                    // Obsah
                    Text(
                      'Obsah poznámky:',
                      style:
                          Theme.of(
                            context,
                          ).textTheme.bodyLarge, // bodyLarge místo bodyText1
                    ),
                    SizedBox(height: 8),
                    Text(
                      _note['body'], // Zobrazení textu poznámky
                      style:
                          Theme.of(
                            context,
                          ).textTheme.bodySmall, // bodySmall místo bodyText2
                    ),
                  ],
                ),
      ),
    );
  }
}
