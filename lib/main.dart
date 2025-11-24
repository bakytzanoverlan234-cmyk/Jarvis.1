import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'core/hybrid_ai.dart';

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
  final HybridAI ai = HybridAI();
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();

  final TextEditingController controller = TextEditingController();
  final ScrollController scroll = ScrollController();

  List<Map<String, String>> messages = [];

  bool voiceEnabled = true;
  bool autoRead = false;
  String voiceGender = "female";

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

    setState(() {
      messages.add({"role": "user", "text": text});
    });

    final reply = await ai.respond(text);

    setState(() {
      messages.add({"role": "ai", "text": reply});
    });

    if (voiceEnabled) {
      await tts.speak(reply);
    }
  }
void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1B2F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Голосовые настройки",
                    style: TextStyle(color: Colors.cyanAccent, fontSize: 18),
                  ),
                  SwitchListTile(
                    title: const Text("Включить озвучку", style: TextStyle(color: Colors.white)),
                    value: voiceEnabled,
                    onChanged: (v) => setModalState(() => voiceEnabled = v),
                  ),
                  SwitchListTile(
                    title: const Text("Авто чтение", style: TextStyle(color: Colors.white)),
                    value: autoRead,
                    onChanged: (v) => setModalState(() => autoRead = v),
                  ),
                  const SizedBox(height: 10),
                  const Text("Выбор голоса", style: TextStyle(color: Colors.white70)),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text("Женский"),
                        selected: voiceGender == "female",
                        onSelected: (_) => setModalState(() => voiceGender = "female"),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text("Мужской"),
                        selected: voiceGender == "male",
                        onSelected: (_) => setModalState(() => voiceGender = "male"),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F1A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Ereke AI"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final msg = messages[i];
                final isUser = msg["role"] == "user";
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.cyanAccent : Colors.deepPurple,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg["text"] ?? "",
                      style: TextStyle(color: isUser ? Colors.black : Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 8),
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
              ],
            ),
          )
        ],
      ),
    );
  }
}
