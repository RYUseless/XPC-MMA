// urls.dart
class ApiUrls {
  // Základní URL pro Django API
  static const String baseUrl = 'http://127.0.0.1:8000/';

  // Endpointy pro poznámky
  static String getNotes() {
    return '${baseUrl}notes/';
  }

  static String getNoteById(int id) {
    return '${baseUrl}notes/$id/';
  }

  static String createNote() {
    return '${baseUrl}notes/create/';
  }

  static String updateNote(int id) {
    return '${baseUrl}notes/update/$id/';
  }

  static String deleteNote(int id) {
    return '${baseUrl}notes/delete/$id/';
  }
}
