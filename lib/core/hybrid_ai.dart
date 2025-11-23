import 'dart:convert';
import 'package:http/http.dart' as http;

class HybridAI {
  // Ключ приходит из --dart-define=GROQ_API_KEY=...
  final String apiKey = const String.fromEnvironment("GROQ_API_KEY");

  // История диалога для контекста
  final List<Map<String, String>> _history = [];

  Future<String> respond(String prompt) async {
    if (apiKey.isEmpty) {
      return "Groq API ключ не передан в приложение.";
    }

    // Добавляем последнюю реплику пользователя в историю
    _history.add({"role": "user", "content": prompt});

    // Формируем сообщения для Groq
    final messages = <Map<String, String>>[
      {
        "role": "system",
        "content":
            "Ты умный персональный ассистент Ereke AI. Отвечай дружелюбно и по делу, на русском языке."
      },
      ..._history,
    ];

    try {
      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "llama3-8b-8192",
          "messages": messages,
        }),
      );

      if (response.statusCode != 200) {
        return "Ошибка Groq: ${response.statusCode}";
      }

      final data = jsonDecode(response.body);
      final text =
          data["choices"][0]["message"]["content"].toString().trim();

      // Добавляем ответ ассистента в историю
      _history.add({"role": "assistant", "content": text});

      // Ограничиваем историю, чтобы не пухла
      if (_history.length > 20) {
        _history.removeRange(0, _history.length - 20);
      }

      return text;
    } catch (e) {
      return "Ошибка подключения к Groq: $e";
    }
  }

  void clearHistory() {
    _history.clear();
  }
}
