import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'core/jarvis_engine.dart';
import 'core/hybrid_ai.dart';

void main() {
  runApp(const JarvisApp());
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController controller = TextEditingController();
  final JarvisEngine jarvis = JarvisEngine();
  final HybridAI ai = HybridAI();
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();

  List<Map<String, String>> messages = [];
  bool listening = false;

  @override
  void initState() {
    super.initState();
    tts.setLanguage("ru-RU");
    tts.setSpeechRate(0.5);
  }

  void sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      messages.add({"role": "user", "text": text});
    });

    controller.clear();

    String response = await ai.respond(text);

    setState(() {
      messages.add({"role": "ai", "text": response});
    });

    await tts.speak(response);
  }

  void startListening() async {
    bool available = await speech.initialize();
    if (!available) return;

    setState(() => listening = true);

    speech.listen(onResult: (result) {
      String text = result.recognizedWords;
      if (text.isNotEmpty) {
        sendMessage(text);
      }
    });
  }

  void stopListening() {
    speech.stop();
    setState(() => listening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Ereke AI"),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isUser = msg["role"] == "user";

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Colors.cyanAccent.withOpacity(0.8)
                          : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg["text"]!,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Напиши Jarvis...",
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                  ),
                  onSubmitted: sendMessage,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.cyanAccent),
                onPressed: () => sendMessage(controller.text),
              ),
              IconButton(
                icon: Icon(
                  listening ? Icons.stop : Icons.mic,
                  color: listening ? Colors.red : Colors.cyanAccent,
                ),
                onPressed: listening ? stopListening : startListening,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
