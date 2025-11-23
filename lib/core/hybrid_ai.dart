import 'dart:convert';
import 'package:http/http.dart' as http;

class HybridAI {
  final String apiKey = "ВСТАВЬ_СЮДА_ТВОЙ_GROQ_API_KEY";

  Future<String> respond(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "llama3-8b-8192",
          "messages": [
            {"role": "system", "content": "Ты умный ассистент по имени Ereke AI. Отвечай на русском."},
            {"role": "user", "content": prompt}
          ]
        }),
      );

      if (response.statusCode != 200) {
        return "Ошибка Groq: ${response.statusCode} ${response.body}";
      }

      final data = jsonDecode(response.body);
      return data["choices"][0]["message"]["content"].toString();
    } catch (e) {
      return "Ошибка подключения к ИИ: $e";
    }
  }
}
