// lib/core/hybrid_ai.dart
//
// HybridAI: текстовый ИИ (через OpenRouter) + хук на музыку и картинки.

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'jarvis_persona.dart';
import 'media_services.dart';

class HybridAI {
  // Ключ OpenRouter (у тебя уже настроен через GitHub Secrets)
  static const String apiKey = String.fromEnvironment('OPENROUTER_API_KEY');

  final String apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
  final JarvisPersona persona = JarvisPersona();

  final List<Map<String, String>> _history = [];

  final MediaServices media;

  HybridAI({MediaServices? media}) : media = media ?? MediaServices();

  void clearHistory() {
    _history.clear();
  }

  // --- Определение типа запроса по тексту ---

  bool _isMusicRequest(String text) {
    final t = text.toLowerCase();
    return t.contains('музыку') ||
        t.contains('трек') ||
        t.contains('песню') ||
        t.contains('саундтрек') ||
        t.contains('бит') ||
        t.contains('биточек');
  }

  bool _isImageRequest(String text) {
    final t = text.toLowerCase();
    return t.contains('картинку') ||
        t.contains('картинка') ||
        t.contains('изображение') ||
        t.contains('артистку') ||
        t.contains('art') ||
        t.contains('аниме арты');
  }

  bool _isImageEditRequest(String text) {
    final t = text.toLowerCase();
    return t.contains('убери людей') ||
        t.contains('удали людей') ||
        t.contains('убери фон') ||
        t.contains('замени фон') ||
        t.contains('очисти фото') ||
        t.contains('ретушь');
  }

  // --- Основной метод ответа ---

  /// [prompt] – сообщение пользователя.
  ///
  /// [imageBase64] передаём, когда хотим редактировать фото,
  /// сейчас UI этого ещё не делает, но архитектура готова.
  Future<String> respond(
    String prompt, {
    String? imageBase64,
  }) async {
    final text = prompt.trim();
    if (text.isEmpty) return 'Скажи мне что-нибудь, брат.';

    // 1) Музыка
    if (_isMusicRequest(text)) {
      final musicAnswer =
          await media.generateMusic('Сделай трек по описанию: $text');
      return '🎶 Музыкальный режим\n$musicAnswer';
    }

    // 2) Картинка (генерация)
    if (_isImageRequest(text) && imageBase64 == null) {
      final imgAnswer =
          await media.generateImage('Нарисуй по описанию: $text');
      return '🖼 Режим картинок\n$imgAnswer';
    }

    // 3) Картинка (редактирование существующего фото)
    if (_isImageEditRequest(text) && imageBase64 != null) {
      final editAnswer = await media.editImage(
        instruction: text,
        base64Image: imageBase64,
      );
      return '🧹 Редактирование фото\n$editAnswer';
    }

    // 4) Обычный интеллектуальный чат через OpenRouter
    if (apiKey.isEmpty) {
      return '❌ OPENROUTER_API_KEY не найден. Проверь dart-define и GitHub Secrets.';
    }

    if (_history.isEmpty) {
      _history.add({
        'role': 'system',
        'content': persona.systemPrompt,
      });
    }

    _history.add({'role': 'user', 'content': text});

    try {
      final resp = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer':
              'https://github.com/bakytzanoverlan234-cmyk/Jarvis.1', // любая твоя ссылка
          'X-Title': 'Ereke AI',
        },
        body: jsonEncode({
          'model': 'openai/gpt-4o-mini',
          'messages': _history,
          'temperature': 0.7,
          'max_tokens': 1500,
        }),
      );

      if (resp.statusCode != 200) {
        return 'Ошибка OpenRouter: ${resp.statusCode}\n${resp.body}';
      }

      final decoded = jsonDecode(resp.body);
      final reply = decoded['choices'][0]['message']['content'] as String;

      _history.add({'role': 'assistant', 'content': reply});
      return reply;
    } catch (e) {
      return 'Ошибка подключения к OpenRouter: $e';
    }
  }
}
