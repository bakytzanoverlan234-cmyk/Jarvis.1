import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'core/hybrid_ai.dart';
import 'core/jarvis_engine.dart';

void main() {
  runApp(const ErekeAI());
}

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
  final JarvisEngine jarvis = JarvisEngine();
  final HybridAI ai = HybridAI();
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();

  final TextEditingController controller = TextEditingController();

  List<String> messages = [];
  bool listening = false;

  @override
  void initState() {
    super.initState();
    initSpeech();
  }

  Future<void> initSpeech() async {
    await Permission.microphone.request();

    await tts.setLanguage("ru-RU");
    await tts.setSpeechRate(0.5);

    await speech.initialize(
      onStatus: (status) {
        print("Speech status: $status");
      },
      onError: (error) {
        print("Speech error: $error");
      },
    );
  }

  Future<void> startListening() async {
    bool available = await speech.initialize();
    if (!available) return;

    setState(() => listening = true);

    speech.listen(onResult: (result) async {
      if (!result.finalResult) return;

      String text = result.recognizedWords;

      if (jarvis.wakeWord(text)) {
        setState(() {
          messages.add("✅ Ereke AI активирован");
        });
        return;
      }

      String response = await ai.respond(text);

      setState(() {
        messages.add("Ты: $text");
        messages.add("Ereke AI: $response");
      });

      await tts.speak(response);
    });
  }

  void stopListening() {
    speech.stop();
    setState(() => listening = false);
  }

  Future<void> sendText() async {
    String text = controller.text.trim();
    if (text.isEmpty) return;

    controller.clear();

    String response = await ai.respond(text);

    setState(() {
      messages.add("Ты: $text");
      messages.add("Ereke AI: $response");
    });

    await tts.speak(response);
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
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    messages[index],
                    style: const TextStyle(
                      color: Colors.cyan,
                      fontSize: 16,
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.black,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Напиши Ereke AI...",
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.cyan),
                  onPressed: sendText,
                ),
                IconButton(
                  icon: Icon(
                    listening ? Icons.stop : Icons.mic,
                    color: listening ? Colors.red : Colors.cyan,
                  ),
                  onPressed: listening ? stopListening : startListening,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
