import 'dart:convert';
import 'package:http/http.dart' as http;

class HybridAI {
  final String apiKey = const String.fromEnvironment("GROQ_API_KEY");

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
            {"role": "user", "content": prompt}
          ]
        }),
      );

      final data = jsonDecode(response.body);

      if (data["choices"] == null) {
        return "Ответ не получен от Groq";
      }

      return data["choices"][0]["message"]["content"];
    } catch (e) {
      return "Ошибка ИИ: $e";
    }
  }
}
