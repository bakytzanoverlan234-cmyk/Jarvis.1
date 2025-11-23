import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'core/hybrid_ai.dart';

void main() => runApp(const ErekeAI());

class ErekeAI extends StatelessWidget {
  const ErekeAI({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final HybridAI ai = HybridAI();
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();

  final TextEditingController controller = TextEditingController();

  List<Map<String, String>> messages = [];
  bool listening = false;
  bool typing = false;

  @override
  void initState() {
    super.initState();
    tts.setLanguage("ru-RU");
    tts.setSpeechRate(0.45);
  }

  Future<void> sendText(String text) async {
    setState(() {
      messages.add({"role": "user", "text": text});
      typing = true;
    });

    String response = await ai.respond(text);

    setState(() {
      messages.add({"role": "ai", "text": response});
      typing = false;
    });

    await tts.speak(response);
  }

  Future<void> startListening() async {
    bool available = await speech.initialize();
    if (!available) return;

    setState(() => listening = true);

    speech.listen(onResult: (result) {
      if (result.finalResult) {
        sendText(result.recognizedWords);
        speech.stop();
        setState(() => listening = false);
      }
    });
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
              padding: const EdgeInsets.all(10),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final msg = messages[i];
                bool isUser = msg["role"] == "user";

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Colors.cyan.withOpacity(0.3)
                          : Colors.deepPurple.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg["text"]!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),

          if (typing)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                "Ereke AI печатает...",
                style: TextStyle(color: Colors.cyan),
              ),
            ),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Напиши Ereke AI...",
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.cyan),
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    sendText(controller.text);
                    controller.clear();
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  listening ? Icons.stop : Icons.mic,
                  color: Colors.cyan,
                ),
                onPressed: startListening,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
