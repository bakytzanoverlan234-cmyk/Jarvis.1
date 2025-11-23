import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'core/hybrid_ai.dart';

void main() {
  runApp(const ErekeAIApp());
}

class ErekeAIApp extends StatelessWidget {
  const ErekeAIApp({super.key});

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
  final ScrollController scrollController = ScrollController();

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
    if (text.trim().isEmpty) return;

    controller.clear();

    setState(() {
      messages.add({"role": "user", "text": text});
      typing = true;
    });

    final reply = await ai.respond(text);

    setState(() {
      messages.add({"role": "ai", "text": reply});
      typing = false;
    });

    await tts.speak(reply);
    scrollToBottom();
  }

  Future<void> startListening() async {
    bool available = await speech.initialize();
    if (!available) return;

    setState(() => listening = true);

    speech.listen(onResult: (result) {
      if (result.finalResult) {
        setState(() => listening = false);
        speech.stop();
        sendText(result.recognizedWords);
      }
    });
  }

  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void clearChat() {
    setState(() {
      messages.clear();
      ai.clearHistory();
    });
  }

  Widget buildBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF00E5FF) : const Color(0xFF23243C),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.black : Colors.white,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          "Ereke AI",
          style: TextStyle(
            color: Colors.cyanAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.cyanAccent),
            onPressed: clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return buildBubble(
                  msg["text"] ?? "",
                  msg["role"] == "user",
                );
              },
            ),
          ),

          if (typing)
            const Padding(
              padding: EdgeInsets.all(6),
              child: Text(
                "Ereke AI печатает...",
                style: TextStyle(color: Colors.cyan),
              ),
            ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1B2F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Напиши Ereke AI...",
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                    onSubmitted: sendText,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.cyanAccent),
                  onPressed: () => sendText(controller.text),
                ),
                IconButton(
                  icon: Icon(
                    listening ? Icons.stop : Icons.mic,
                    color: Colors.cyanAccent,
                  ),
                  onPressed:
                      listening ? () => speech.stop() : startListening,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
