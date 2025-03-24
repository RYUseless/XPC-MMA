import 'package:http/http.dart' as http;
import 'dart:convert';

// Funkce pro smazání poznámky
Future<void> deleteNote(int noteId) async {
  final String apiUrl = 'http://127.0.0.1:8000/notes/delete/$noteId/';

  try {
    final response = await http.delete(
      Uri.parse(apiUrl),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode != 200) {
      final errorMessage =
          jsonDecode(response.body)['error'] ?? 'Neznámá chyba';
      print('Chyba při smazání: $errorMessage');
    }
  } catch (e) {
    print('Chyba při komunikaci s backendem: $e');
  }
}
