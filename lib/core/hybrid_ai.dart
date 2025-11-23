import 'dart:convert';
import 'package:http/http.dart' as http;
import 'music_engine.dart';
import 'jarvis_persona.dart';

class HybridAI {
  static const String apiKey = String.fromEnvironment('GROQ_API_KEY');
  final String apiUrl = "https://api.groq.com/openai/v1/chat/completions";

  final List<Map<String, String>> _history = [];
  final MusicEngine music = MusicEngine();
  final JarvisPersona persona = JarvisPersona();

  void clearHistory() {
    _history.clear();
  }

  Future<String> respond(String prompt) async {
    if (apiKey.isEmpty) {
      return "❌ API ключ Groq не найден. Проверь dart-define.";
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
        },
        body: jsonEncode({
          "model": "llama3-70b-8192",
          "messages": _history,
        }),
      );

      if (response.statusCode != 200) {
        return "Ошибка Groq: ${response.statusCode}\n${response.body}";
      }

      final decoded = jsonDecode(response.body);
      final reply = decoded['choices'][0]['message']['content'];

      _history.add({"role": "assistant", "content": reply});
      return reply;
    } catch (e) {
      return "Ошибка соединения с Groq: $e";
    }
  }
}
