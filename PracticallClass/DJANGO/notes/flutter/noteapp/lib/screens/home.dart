import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'create.dart'; // Importujeme stránku pro vytváření poznámek
import 'update.dart'; // Importujeme stránku pro úpravu poznámky
import 'note.dart'; // Importujeme stránku pro detail poznámky
import 'urls.dart'; // Importujeme soubor s URL
import 'delete.dart'; // Importujeme funkci pro smazání poznámky

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> _notes = [];

  // Funkce pro načtení všech poznámek
  Future<void> _fetchNotes() async {
    try {
      final response = await http.get(Uri.parse(ApiUrls.getNotes()));

      if (response.statusCode == 200) {
        setState(() {
          _notes = jsonDecode(response.body); // get notes z api jebnute
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Chyba při načítání poznámek.')));
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
    _fetchNotes(); // Načteme poznámky při inicializaci
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Seznam poznámek')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              // Odkaz na stránku pro vytvoření nové poznámky
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => CreatePage(
                        onNoteCreated:
                            _fetchNotes, // Předáme callback pro reload
                      ),
                ),
              );
            },
            child: Text('Vytvořit novou poznámku'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                return ListTile(
                  title: Text(note['body']), // Zobrazení pouze obsahu
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ikona pro úpravu
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () {
                          // Při kliknutí na ikonu editace přejdeme na stránku pro úpravu
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => UpdatePage(
                                    noteId: note['id'],
                                    onNoteUpdated:
                                        _fetchNotes, // Předáme callback pro reload
                                  ),
                            ),
                          );
                        },
                      ),
                      // Ikona pro smazání
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () async {
                          // Zavoláme funkci pro smazání
                          final confirmDelete = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text('Potvrzení smazání'),
                                content: Text(
                                  'Opravdu chcete smazat tuto poznámku?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(false),
                                    child: Text('Zrušit'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(true),
                                    child: Text('Smazat'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (confirmDelete == true) {
                            // Pokud uživatel potvrdí, smažeme poznámku
                            await deleteNote(note['id']);
                            // Zavoláme funkci pro opětovné načtení seznamu poznámek
                            _fetchNotes();
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    // Při kliknutí na položku přejdeme na stránku pro zobrazení detailu poznámky
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => NoteDetailPage(noteId: note['id']),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
