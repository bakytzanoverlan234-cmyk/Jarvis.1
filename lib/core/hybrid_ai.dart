import 'dart:convert';
import 'package:http/http.dart' as http;
import 'jarvis_persona.dart';

class HybridAI {
  static const String apiKey = String.fromEnvironment('OPENROUTER_API_KEY');

  final String apiUrl = "https://openrouter.ai/api/v1/chat/completions";
  final JarvisPersona persona = JarvisPersona();

  final List<Map<String, String>> _history = [];

  void clearHistory() {
    _history.clear();
  }

  Future<String> respond(String prompt) async {
    if (apiKey.isEmpty) {
      return "❌ OPENROUTER_API_KEY не найден. Проверь dart-define.";
    }

    if (_history.isEmpty) {
      _history.add({
        "role": "system",
        "content": persona.systemPrompt,
      });
    }

    _history.add({"role": "user", "content": prompt});

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
          "HTTP-Referer": "https://github.com/bakytzanoverlan234-cmyk/Jarvis.1",
          "X-Title": "Ereke AI"
        },
        body: jsonEncode({
          "model": "openai/gpt-4o-mini",
          "messages": _history,
          "temperature": 0.7,
          "max_tokens": 1500
        }),
      );

      if (response.statusCode != 200) {
        return "Ошибка OpenRouter: ${response.statusCode}\n${response.body}";
      }

      final decoded = jsonDecode(response.body);
      final reply = decoded['choices'][0]['message']['content'];

      _history.add({"role": "assistant", "content": reply});
      return reply;
    } catch (e) {
      return "Ошибка подключения к OpenRouter: $e";
    }
  }
}
