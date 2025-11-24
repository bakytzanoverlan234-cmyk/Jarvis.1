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

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatBubble({super.key, required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.cyanAccent.withOpacity(0.2) : const Color(0xFF1A1E3F),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white),
        ),
      ),
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

  bool voiceEnabled = true;
  bool listening = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await tts.setLanguage("ru-RU");
    await tts.setSpeechRate(0.45);
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      messages.add({"role": "user", "text": text});
    });

    controller.clear();

    final response = await ai.respond(text);

    setState(() {
      messages.add({"role": "ai", "text": response});
    });

    if (voiceEnabled) {
      await tts.speak(response);
    }

    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _startListening() async {
    bool available = await speech.initialize();
    if (!available) return;

    setState(() => listening = true);

    speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _sendMessage(result.recognizedWords);
          setState(() => listening = false);
        }
      },
    );
  }

  void _toggleVoice() {
    setState(() {
      voiceEnabled = !voiceEnabled;
    });
  }
@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F1A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "Ereke AI",
          style: TextStyle(color: Colors.cyanAccent),
        ),
        actions: [
          IconButton(
            tooltip: voiceEnabled ? "Озвучка включена" : "Озвучка выключена",
            icon: Icon(
              voiceEnabled ? Icons.volume_up : Icons.volume_off,
              color: Colors.cyanAccent,
            ),
            onPressed: _toggleVoice,
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
              itemBuilder: (context, i) {
                final msg = messages[i];
                final isUser = msg["role"] == "user";

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Colors.cyan.withOpacity(0.25)
                          : Colors.deepPurple.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg["text"] ?? "",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1B2F),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Напиши Ereke AI...",
                      hintStyle: TextStyle(color: Colors.white60),
                      border: InputBorder.none,
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.cyanAccent),
                  onPressed: () => _sendMessage(controller.text),
                ),
                IconButton(
                  icon: Icon(
                    listening ? Icons.stop : Icons.mic,
                    color: Colors.cyanAccent,
                  ),
                  onPressed: listening ? null : _startListening,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ================= НАСТРОЙКИ =================

class SettingsScreen extends StatefulWidget {
  final bool voiceEnabled;
  final String voiceGender;
  final double voiceRate;
  final Function(bool, String, double) onChanged;

  const SettingsScreen({
    super.key,
    required this.voiceEnabled,
    required this.voiceGender,
    required this.voiceRate,
    required this.onChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _voiceEnabled;
  late String _voiceGender;
  late double _voiceRate;

  @override
  void initState() {
    super.initState();
    _voiceEnabled = widget.voiceEnabled;
    _voiceGender = widget.voiceGender;
    _voiceRate = widget.voiceRate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F1A),
      appBar: AppBar(
        title: const Text("Настройки Ereke AI"),
        backgroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          const Text(
            "Голосовой ассистент",
            style: TextStyle(
              color: Colors.cyanAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          SwitchListTile(
            title: const Text(
              "Включить озвучку",
              style: TextStyle(color: Colors.white),
            ),
            value: _voiceEnabled,
            onChanged: (v) => setState(() => _voiceEnabled = v),
          ),

          const SizedBox(height: 10),

          const Text(
            "Скорость речи",
            style: TextStyle(color: Colors.white),
          ),
          Slider(
            value: _voiceRate,
            min: 0.2,
            max: 0.8,
            divisions: 6,
            label: _voiceRate.toStringAsFixed(2),
            onChanged: (v) => setState(() => _voiceRate = v),
          ),

          const SizedBox(height: 20),

          const Text(
            "Выбор голоса",
            style: TextStyle(
              color: Colors.cyanAccent,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              ChoiceChip(
                label: const Text("Женский"),
                selected: _voiceGender == "female",
                onSelected: (_) {
                  setState(() => _voiceGender = "female");
                },
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: const Text("Мужской"),
                selected: _voiceGender == "male",
                onSelected: (_) {
                  setState(() => _voiceGender = "male");
                },
              ),
            ],
          ),

          const SizedBox(height: 30),

          const Text(
            "Режимы ассистента",
            style: TextStyle(
              color: Colors.cyanAccent,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 10),

          ListTile(
            title: const Text("💬 Чат Ereke AI",
                style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              "Основной интеллектуальный режим",
              style: TextStyle(color: Colors.white70),
            ),
          ),

          ListTile(
            title: const Text("🎵 Музыка (будет добавлено)",
                style: TextStyle(color: Colors.white54)),
          ),

          ListTile(
            title: const Text("🖼 Генерация изображений (будет добавлено)",
                style: TextStyle(color: Colors.white54)),
          ),

          const SizedBox(height: 30),

          ElevatedButton(
            onPressed: () async {
              widget.onChanged(
                _voiceEnabled,
                _voiceGender,
                _voiceRate,
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
            ),
            child: const Text("Сохранить настройки"),
          ),
        ],
      ),
    );
  }
}

