import 'dart:convert';
import 'package:http/http.dart' as http;

class HybridAI {
  static const String apiKey = String.fromEnvironment('GROQ_API_KEY');

  Future<String> respond(String message) async {
    try {
      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey",
        },
        body: jsonEncode({
          "model": "llama3-70b-8192",
          "messages": [
            {
              "role": "system",
              "content": "Ты умный ассистент по имени Ereke AI. Отвечай на русском."
            },
            {
              "role": "user",
              "content": message
            }
          ],
          "temperature": 0.7
        }),
      );

      if (response.statusCode != 200) {
        return "Ошибка Groq: ${response.statusCode}";
      }

      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'].toString();

    } catch (e) {
      return "Ошибка ИИ: $e";
    }
  }
}
