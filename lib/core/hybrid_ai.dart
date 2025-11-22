import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

class HybridAI {
  final String groqApiKey = const String.fromEnvironment('GROQ_API_KEY');

  Future<String> respond(String prompt) async {
    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity != ConnectivityResult.none) {
      return await _groqResponse(prompt);
    } else {
      return await _ollamaResponse(prompt);
    }
  }

  Future<String> _groqResponse(String prompt) async {
    final url = Uri.parse("https://api.groq.com/openai/v1/chat/completions");

    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $groqApiKey",
        "Content-Type": "application/json"
      },
      body: jsonEncode({
        "model": "llama3-8b-8192",
        "messages": [
          {"role": "user", "content": prompt}
        ]
      }),
    );

    final data = jsonDecode(response.body);
    return data["choices"][0]["message"]["content"];
  }

  Future<String> _ollamaResponse(String prompt) async {
    final response = await http.post(
      Uri.parse("http://127.0.0.1:11434/api/generate"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "model": "llama3",
        "prompt": prompt,
        "stream": false
      }),
    );

    final data = jsonDecode(response.body);
    return data["response"];
  }
}
