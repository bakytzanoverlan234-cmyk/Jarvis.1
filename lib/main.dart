import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'core/jarvis_engine.dart';
import 'core/hybrid_ai.dart';

void main() {
  runApp(const JarvisApp());
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: JarvisHome(),
    );
  }
}

class JarvisHome extends StatefulWidget {
  const JarvisHome({super.key});

  @override
  State<JarvisHome> createState() => _JarvisHomeState();
}

class _JarvisHomeState extends State<JarvisHome> {
  final JarvisEngine jarvis = JarvisEngine();
  final HybridAI ai = HybridAI();
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();

  final TextEditingController textController = TextEditingController();
  List<String> messages = [];

  bool listening = false;

  @override
  void initState() {
    super.initState();
    requestMicPermission();
    tts.setLanguage("ru-RU");
    tts.setSpeechRate(0.5);
  }

  Future<void> requestMicPermission() async {
    if (!await Permission.microphone.isGranted) {
      await Permission.microphone.request();
    }
  }

  Future<void> processText(String text) async {
    if (text.isEmpty) return;

    setState(() {
      messages.add("Ты: $text");
    });

    String response = await ai.respond(text);

    setState(() {
      messages.add("Jarvis: $response");
    });

    await tts.speak(response);
  }

  void startListening() async {
    bool available = await speech.initialize();
    if (!available) return;

    setState(() => listening = true);

    speech.listen(onResult: (result) async {
      String text = result.recognizedWords;

      if (jarvis.wakeWord(text)) return;

      await processText(text);
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
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    messages[index],
                    style: const TextStyle(color: Colors.cyan, fontSize: 16),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Напиши Jarvis...",
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.cyan),
                onPressed: () {
                  processText(textController.text);
                  textController.clear();
                },
              ),
              FloatingActionButton(
                backgroundColor: listening ? Colors.red : Colors.cyan,
                onPressed: listening ? stopListening : startListening,
                child: Icon(listening ? Icons.stop : Icons.mic),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
