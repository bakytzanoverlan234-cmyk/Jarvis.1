import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'core/jarvis_engine.dart';

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
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();

  String status = "Скажи: брат...";
  bool listening = false;

  @override
  void initState() {
    super.initState();
    tts.setLanguage("ru-RU");
  }

  void startListening() async {
    bool available = await speech.initialize();
    if (!available) return;

    setState(() => listening = true);

    speech.listen(onResult: (result) async {
      String text = result.recognizedWords;
      if (jarvis.wakeWord(text)) {
        status = "Jarvis активирован";
      }
      String response = await jarvis.respond(text);
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
            Text(status,
                style: const TextStyle(color: Colors.cyan, fontSize: 20),
                textAlign: TextAlign.center),
            const SizedBox(height: 40),
            FloatingActionButton(
              backgroundColor: listening ? Colors.red : Colors.cyan,
              onPressed: listening ? stopListening : startListening,
              child: Icon(listening ? Icons.stop : Icons.mic),
            )
          ],
        ),
      ),
    );
  }
}
