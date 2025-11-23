import 'dart:convert';
import 'package:http/http.dart' as http;

class HybridAI {
  static const String apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const String apiUrl = 'https://api.groq.com/openai/v1/chat/completions';

  final List<Map<String, String>> _history = [];

  /// Очистка памяти диалога
  void clearHistory() {
    _history.clear();
  }

  Future<String> respond(String prompt) async {
    if (apiKey.isEmpty) {
      return "API ключ Groq не задан";
    }

    _history.add({"role": "user", "content": prompt});

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": "llama3-8b-8192",
          "messages": _history,
          "temperature": 0.7
        }),
      );

      if (response.statusCode != 200) {
        return "Ошибка Groq: ${response.statusCode}";
      }

      final data = jsonDecode(response.body);
      final reply = data['choices'][0]['message']['content'];

      _history.add({"role": "assistant", "content": reply});

      return reply.trim();
    } catch (e) {
      return "Ошибка ИИ: $e";
    }
  }
}
