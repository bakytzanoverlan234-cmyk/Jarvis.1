import 'dart:convert';
import 'package:http/http.dart' as http;
import 'jarvis_persona.dart';

/// Гибридный ИИ, работающий через OpenRouter + Jarvis-персона.
class HybridAI {
  /// Ключ берём только из --dart-define, чтобы не светить его в коде.
  static const String apiKey =
      String.fromEnvironment('OPENROUTER_API_KEY');

  /// Эндпоинт OpenRouter
  final String apiUrl = "https://openrouter.ai/api/v1/chat/completions";

  /// Персона Джарвиса / Ereke AI
  final JarvisPersona persona = JarvisPersona();

  /// История диалога для контекста
  final List<Map<String, String>> _history = [];

  void clearHistory() {
    _history.clear();
  }

  /// Основной метод ответа от ИИ
  Future<String> respond(String prompt) async {
    if (apiKey.isEmpty) {
      return "❌ OPENROUTER_API_KEY не найден. "
          "Собери APK через GitHub Actions c --dart-define.";
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
          // Эти два хедера требуют OpenRouter:
          "HTTP-Referer":
              "https://github.com/bakytzanoverlan234-cmyk/Jarvis.1",
          "X-Title": "Ereke AI Assistant",
        },
        body: jsonEncode({
          // Можешь сменить модель при желании, например:
          // "model": "openai/gpt-4.1-mini",
          "model": "openai/gpt-4o-mini",
          "messages": _history,
          "temperature": 0.7,
          "max_tokens": 1500,
        }),
      );

      if (response.statusCode != 200) {
        return "Ошибка OpenRouter: ${response.statusCode}\n${response.body}";
      }

      final decoded = jsonDecode(response.body);
      final reply = decoded['choices'][0]['message']['content'] as String;

      _history.add({"role": "assistant", "content": reply});
      return reply;
    } catch (e) {
      return "Ошибка подключения к OpenRouter: $e";
    }
  }
}
