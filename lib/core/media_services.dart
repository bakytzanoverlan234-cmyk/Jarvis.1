// lib/core/media_services.dart
//
// Универсальные сервисы для музыки и картинок.
// Здесь НЕТ ключей, все ключи берём из --dart-define и GitHub Secrets.

import 'dart:convert';
import 'package:http/http.dart' as http;

class MediaServices {
  // ---------- МУЗЫКА ----------

  /// Ключ и URL для сервиса музыки (Stable Audio, Suno API и т.п.).
  /// Задаёшь через:
  /// flutter build ... --dart-define=MUSIC_API_KEY=xxx --dart-define=MUSIC_API_URL=yyy
  static const String musicApiKey = String.fromEnvironment('MUSIC_API_KEY');
  static const String musicApiUrl = String.fromEnvironment('MUSIC_API_URL');

  /// Сгенерировать трек по тексту.
  /// Возвращает либо URL/описание трека, либо текст ошибки.
  Future<String> generateMusic(String prompt) async {
    if (musicApiKey.isEmpty || musicApiUrl.isEmpty) {
      return '❌ MUSIC_API_KEY или MUSIC_API_URL не заданы. Добавь их в GitHub Secrets и --dart-define.';
    }

    try {
      // Пример универсального POST-запроса.
      // В реальном API поменяй body и разбор ответа по документации сервиса.
      final resp = await http.post(
        Uri.parse(musicApiUrl),
        headers: {
          'Authorization': 'Bearer $musicApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          // Для Stable Audio / другого сервиса смотри их docs и меняй поля:
          'prompt': prompt,
          'duration': 60, // пример: длина трека в секундах
        }),
      );

      if (resp.statusCode != 200) {
        return 'Ошибка сервиса музыки: ${resp.statusCode}\n${resp.body}';
      }

      final data = jsonDecode(resp.body);

      // Популярные варианты структур (подправишь под свой API):
      // 1) {"audio_url": "https://..."}
      // 2) {"result": {"url": "..."}}
      final url = data['audio_url'] ??
          (data['result'] != null ? data['result']['url'] : null);

      if (url is String && url.isNotEmpty) {
        return '🎵 Трек сгенерирован: $url';
      }

      return 'Музыка сгенерирована, но я не смог найти URL в ответе сервиса.';
    } catch (e) {
      return 'Ошибка при запросе к сервису музыки: $e';
    }
  }

  // ---------- КАРТИНКИ: ГЕНЕРАЦИЯ ----------

  static const String imageApiKey = String.fromEnvironment('IMAGE_API_KEY');
  static const String imageApiUrl = String.fromEnvironment('IMAGE_API_URL');

  /// Генерация картинки по тексту.
  /// Может вернуть URL или base64-строку — зависит от сервиса.
  Future<String> generateImage(String prompt) async {
    if (imageApiKey.isEmpty || imageApiUrl.isEmpty) {
      return '❌ IMAGE_API_KEY или IMAGE_API_URL не заданы.';
    }

    try {
      final resp = await http.post(
        Uri.parse(imageApiUrl),
        headers: {
          'Authorization': 'Bearer $imageApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          // Для OpenRouter + gpt-image-1 через совместимый endpoint
          // структуру подгони под конкретный API.
          'prompt': prompt,
        }),
      );

      if (resp.statusCode != 200) {
        return 'Ошибка сервиса картинок: ${resp.statusCode}\n${resp.body}';
      }

      final data = jsonDecode(resp.body);

      // Часто встречающиеся варианты:
      // 1) {"data":[{"url":"https://..."}]}
      // 2) {"image_url":"https://..."}
      // 3) {"data":[{"b64_json":"..."}]}
      String? urlOrBase64;

      if (data is Map && data['data'] is List && data['data'].isNotEmpty) {
        final first = data['data'][0];
        if (first is Map && first['url'] is String) {
          urlOrBase64 = first['url'];
        } else if (first is Map && first['b64_json'] is String) {
          urlOrBase64 = 'data:image/png;base64,${first['b64_json']}';
        }
      } else if (data['image_url'] is String) {
        urlOrBase64 = data['image_url'];
      }

      if (urlOrBase64 == null) {
        return 'Картинка сгенерирована, но URL/base64 не найден в ответе.';
      }

      return '🖼 Картинка готова: $urlOrBase64';
    } catch (e) {
      return 'Ошибка при запросе к сервису картинок: $e';
    }
  }

  // ---------- КАРТИНКИ: РЕДАКТИРОВАНИЕ (УБРАТЬ ЛЮДЕЙ, ИЗМЕНИТЬ ФОН И Т.П.) ----------

  static const String imageEditApiKey =
      String.fromEnvironment('IMAGE_EDIT_API_KEY');
  static const String imageEditApiUrl =
      String.fromEnvironment('IMAGE_EDIT_API_URL');

  /// Редактирование картинки.
  ///
  /// [instruction] – что сделать: "убери лишних людей на заднем плане",
  /// [base64Image] – исходное изображение в base64 (без prefix data:image/...).
  Future<String> editImage({
    required String instruction,
    required String base64Image,
  }) async {
    if (imageEditApiKey.isEmpty || imageEditApiUrl.isEmpty) {
      return '❌ IMAGE_EDIT_API_KEY или IMAGE_EDIT_API_URL не заданы.';
    }

    try {
      final resp = await http.post(
        Uri.parse(imageEditApiUrl),
        headers: {
          'Authorization': 'Bearer $imageEditApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          // Для ClipDrop / другого image-edit API подгони формат:
          'instruction': instruction,
          'image_base64': base64Image,
        }),
      );

      if (resp.statusCode != 200) {
        return 'Ошибка редактирования картинки: ${resp.statusCode}\n${resp.body}';
      }

      final data = jsonDecode(resp.body);

      // Аналогично генерации:
      String? urlOrBase64;

      if (data['edited_url'] is String) {
        urlOrBase64 = data['edited_url'];
      } else if (data['b64_json'] is String) {
        urlOrBase64 = 'data:image/png;base64,${data['b64_json']}';
      }

      if (urlOrBase64 == null) {
        return 'Редактирование выполнено, но выходная картинка не найдена в ответе.';
      }

      return '🧹 Отредактированное изображение: $urlOrBase64';
    } catch (e) {
      return 'Ошибка при запросе к сервису редактирования картинок: $e';
    }
  }
}
