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

  final ScrollController _scroll = ScrollController();

  List<Map<String, String>> messages = [];
  bool listening = false;
  bool typing = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await tts.setLanguage("ru-RU");
    await tts.setSpeechRate(0.45);
  }

  Future<void> _sendText(String text) async {
    if (text.trim().isEmpty) return;

    controller.clear();

    setState(() {
      messages.add({"role": "user", "text": text.trim()});
      typing = true;
    });
    _scrollToBottom();

    final reply = await ai.respond(text.trim());

    setState(() {
      messages.add({"role": "ai", "text": reply});
      typing = false;
    });
    _scrollToBottom();

    await tts.speak(reply);
  }

  Future<void> _startListening() async {
    bool available = await speech.initialize();
    if (!available) return;

    setState(() => listening = true);

    speech.listen(onResult: (result) {
      if (result.finalResult) {
        listening = false;
        speech.stop();
        _sendText(result.recognizedWords);
        setState(() {});
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      messages.clear();
      ai.clearHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Ereke AI"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(10),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final msg = messages[i];
                final isUser = msg["role"] == "user";

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Colors.cyan.withOpacity(0.3)
                          : Colors.deepPurple.withOpacity(0.4),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                    ),
                    child: Text(
                      msg["text"] ?? "",
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),

          if (typing)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                "Ereke AI печатает...",
                style: TextStyle(color: Colors.cyan),
              ),
            ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                    onSubmitted: _sendText,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.cyan),
                  onPressed: () => _sendText(controller.text),
                ),
                IconButton(
                  icon: Icon(
                    listening ? Icons.stop : Icons.mic,
                    color: Colors.cyan,
                  ),
                  onPressed: listening ? speech.stop : _startListening,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
