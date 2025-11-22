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

  String status = "Скажи: брат...";
  bool listening = false;

  @override
  void initState() {
    super.initState();
    requestMicPermission();
    tts.setLanguage("ru-RU");
    tts.setSpeechRate(0.5);
  }

  Future<void> requestMicPermission() async {
    var perm = await Permission.microphone.status;
    if (!perm.isGranted) {
      await Permission.microphone.request();
    }
  }

  void startListening() async {
    bool available = await speech.initialize();
    if (!available) {
      setState(() => status = "Микрофон недоступен");
      return;
    }

    setState(() => listening = true);

    speech.listen(onResult: (result) async {
      String text = result.recognizedWords;

      if (jarvis.wakeWord(text)) {
        setState(() => status = "Jarvis активирован");
        return;
      }

      String response = await ai.respond(text);
      setState(() => status = response);
      await tts.speak(response);
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              status,
              style: const TextStyle(color: Colors.cyan, fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            FloatingActionButton(
              backgroundColor: listening ? Colors.red : Colors.cyan,
              onPressed: listening ? stopListening : startListening,
              child: Icon(listening ? Icons.stop : Icons.mic),
            ),
          ],
        ),
      ),
    );
  }
}
