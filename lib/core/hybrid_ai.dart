import 'dart:convert';
import 'package:http/http.dart' as http;

class HybridAI {
  // Настрой под себя:
  // true = Ollama (локально)
  // false = Groq (онлайн)
  bool useOllama = true;

  // Ollama URL (если установлен на телефоне или локально)
  final String ollamaUrl = "http://127.0.0.1:11434/api/generate";

  // Groq API
  final String groqApiKey = String.fromEnvironment('GROQ_API_KEY');
  final String groqUrl = "https://api.groq.com/openai/v1/chat/completions";

  Future<String> respond(String prompt) async {
    try {
      if (useOllama) {
        return await _ollamaResponse(prompt);
      } else {
        return await _groqResponse(prompt);
      }
    } catch (e) {
      return "Ошибка ИИ: $e";
    }
  }

  // ===== OLLAMA =====
  Future<String> _ollamaResponse(String prompt) async {
    final response = await http.post(
      Uri.parse(ollamaUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "model": "llama3",
        "prompt": prompt,
        "stream": false
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["response"] ?? "Нет ответа от Ollama";
    } else {
      return "Ollama недоступен";
    }
  }

  // ===== GROQ =====
  Future<String> _groqResponse(String prompt) async {
    final response = await http.post(
      Uri.parse(groqUrl),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $groqApiKey"
      },
      body: jsonEncode({
        "model": "llama3-8b-8192",
        "messages": [
          {"role": "user", "content": prompt}
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      return "Groq недоступен";
    }
  }
}
