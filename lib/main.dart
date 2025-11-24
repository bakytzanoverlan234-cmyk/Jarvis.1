import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/hybrid_ai.dart';

void main() {
  runApp(const ErekeAI());
}

class ErekeAI extends StatelessWidget {
  const ErekeAI({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Ereke AI",
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050712),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

enum ErekeMode { chat, images, music, history }

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  ErekeMode _mode = ErekeMode.chat;

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_mode) {
      case ErekeMode.chat:
        body = const ChatScreen();
        break;
      case ErekeMode.images:
        body = const ImagesScreen();
        break;
      case ErekeMode.music:
        body = const MusicScreen();
        break;
      case ErekeMode.history:
        body = const HistoryScreen();
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050712),
      body: SafeArea(child: body),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0E101F),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.white54,
        currentIndex: _mode.index,
        onTap: (i) {
          setState(() {
            _mode = ErekeMode.values[i];
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: "Чат",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.image_outlined),
            label: "Картинки",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: "Музыка",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "История",
          ),
        ],
      ),
    );
  }
}
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final HybridAI ai = HybridAI();
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();
  final TextEditingController controller = TextEditingController();
  final ScrollController scroll = ScrollController();

  final List<Map<String, String>> messages = [];

  bool voiceEnabled = true;
  bool autoRead = false;
  String voiceGender = "female";
  bool listening = false;

  late AnimationController _coreController;

  @override
  void initState() {
    super.initState();
    _coreController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _loadSettings();
    _initTts();
  }

  @override
  void dispose() {
    _coreController.dispose();
    controller.dispose();
    scroll.dispose();
    tts.stop();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      voiceEnabled = prefs.getBool('voiceEnabled') ?? true;
      autoRead = prefs.getBool('autoRead') ?? false;
      voiceGender = prefs.getString('voiceGender') ?? "female";
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voiceEnabled', voiceEnabled);
    await prefs.setBool('autoRead', autoRead);
    await prefs.setString('voiceGender', voiceGender);
  }

  Future<void> _initTts() async {
    await tts.setLanguage("ru-RU");
    await tts.setSpeechRate(0.45);

    final voices = await tts.getVoices;
    if (voices is List) {
      for (final v in voices) {
        final name = (v['name'] ?? '').toString().toLowerCase();
        if (voiceGender == "female" && name.contains("female")) {
          await tts.setVoice(Map<String, String>.from(v));
          break;
        }
        if (voiceGender == "male" && name.contains("male")) {
          await tts.setVoice(Map<String, String>.from(v));
          break;
        }
      }
    }
  }

  void _addMessage(String role, String text) {
    setState(() {
      messages.add({"role": role, "text": text});
    });
    HistoryStore.instance.add(role, text);
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    controller.clear();

    _addMessage("user", trimmed);

    final reply = await ai.respond(trimmed);
    _addMessage("ai", reply);

    if (voiceEnabled) {
      await tts.stop();
      await tts.speak(reply);
    }
  }

  Future<void> _startListening() async {
    final available = await speech.initialize(
      onStatus: (s) => debugPrint("STT status: $s"),
      onError: (e) => debugPrint("STT error: $e"),
    );
    if (!available) return;

    setState(() => listening = true);

    speech.listen(
      localeId: "ru_RU",
      onResult: (result) async {
        if (result.finalResult) {
          setState(() => listening = false);
          speech.stop();
          await _sendText(result.recognizedWords);
        }
      },
    );
  }

  void _stopListening() {
    speech.stop();
    setState(() => listening = false);
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E101F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        bool localVoiceEnabled = voiceEnabled;
        bool localAutoRead = autoRead;
        String localGender = voiceGender;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 4,
                    width: 40,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    "Настройки голоса",
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text(
                      "Включить озвучку ответов",
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      "Читать вслух ответы Ereke AI",
                      style: TextStyle(color: Colors.white70),
                    ),
                    value: localVoiceEnabled,
                    onChanged: (v) {
                      setModalState(() => localVoiceEnabled = v);
                    },
                  ),
                  SwitchListTile(
                    title: const Text(
                      "Авто-озвучка",
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      "Если включено — все ответы сразу озвучиваются",
                      style: TextStyle(color: Colors.white70),
                    ),
                    value: localAutoRead,
                    onChanged: (v) {
                      setModalState(() => localAutoRead = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Голос ассистента",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text("Женский"),
                        selected: localGender == "female",
                        onSelected: (_) {
                          setModalState(() {
                            localGender = "female";
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text("Мужской"),
                        selected: localGender == "male",
                        onSelected: (_) {
                          setModalState(() {
                            localGender = "male";
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          voiceEnabled = localVoiceEnabled;
                          autoRead = localAutoRead;
                          voiceGender = localGender;
                        });
                        await _saveSettings();
                        await _initTts();
                        if (mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text("Сохранить"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
class JarvisCore extends StatelessWidget {
  final AnimationController controller;
  final bool speaking;

  const JarvisCore({
    super.key,
    required this.controller,
    required this.speaking,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final scale = 1.0 + (speaking ? controller.value * 0.3 : 0.15);
        final opacity = 0.4 + controller.value * 0.4;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.cyanAccent.withOpacity(opacity),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(0.4),
                  blurRadius: 20 + controller.value * 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.7),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

extension on _ChatScreenState {
  bool get _aiSpeaking => voiceEnabled; // простая индикация

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050712),
      appBar: AppBar(
        title: const Text("Ereke AI"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Center(
            child: JarvisCore(
              controller: _coreController,
              speaking: _aiSpeaking,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Онлайн • гибридный Jarvis ассистент",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final msg = messages[i];
                final isUser = msg["role"] == "user";
                return ChatBubble(
                  text: msg["text"] ?? "",
                  isUser: isUser,
                );
              },
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0E101F),
              border: Border(
                top: BorderSide(color: Colors.white12),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    voiceEnabled ? Icons.volume_up : Icons.volume_off,
                    color: voiceEnabled ? Colors.cyanAccent : Colors.white54,
                  ),
                  onPressed: () {
                    setState(() => voiceEnabled = !voiceEnabled);
                    _saveSettings();
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Напиши Ereke AI...",
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                    onSubmitted: _sendText,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.cyanAccent),
                  onPressed: () => _sendText(controller.text),
                ),
                IconButton(
                  icon: Icon(
                    listening ? Icons.stop : Icons.mic,
                    color: listening ? Colors.redAccent : Colors.cyanAccent,
                  ),
                  onPressed: listening ? _stopListening : _startListening,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    final alignment =
        isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bgColor = isUser
        ? Colors.cyanAccent.withOpacity(0.9)
        : const Color(0xFF20223A);
    final textColor = isUser ? Colors.black : Colors.white;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(color: textColor),
        ),
      ),
    );
  }
}

// Хранилище истории для вкладки "История"
class HistoryStore {
  HistoryStore._();

  static final HistoryStore instance = HistoryStore._();

  final List<Map<String, String>> history = [];

  void add(String role, String text) {
    history.add({"role": role, "text": text});
  }
}

// Вкладка "Картинки"
class ImagesScreen extends StatefulWidget {
  const ImagesScreen({super.key});

  @override
  State<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends State<ImagesScreen> {
  final HybridAI ai = HybridAI();
  final TextEditingController controller = TextEditingController();
  String result = "";

  Future<void> _generate() async {
    final prompt = controller.text.trim();
    if (prompt.isEmpty) return;
    setState(() => result = "Генерирую промпт для изображения...");
    final reply = await ai.respond(
      "Сгенерируй подробное текстовое описание изображения по запросу: \"$prompt\". "
      "Запиши только описание сцены, без лишних комментариев.",
    );
    setState(() => result = reply);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050712),
      appBar: AppBar(
        title: const Text("Картинки"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text(
              "Ereke AI поможет придумать промпт для нейросети (Stable Diffusion, DALL·E и т.п.).",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Опиши, что нужно нарисовать...",
                hintStyle: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _generate,
              child: const Text("Сгенерировать промпт"),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  result,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// Вкладка "Музыка"
class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final HybridAI ai = HybridAI();
  final TextEditingController controller = TextEditingController();
  String result = "";

  Future<void> _generate() async {
    final prompt = controller.text.trim();
    if (prompt.isEmpty) return;
    setState(() => result = "Генерирую идею трека...");
    final reply = await ai.respond(
      "Придумай структуру трека (жанр, BPM, атмосфера, инструменты) и текст куплета/припаева по запросу: \"$prompt\". "
      "Ответ выведи кратко, но понятно для музыкального продюсера.",
    );
    setState(() => result = reply);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050712),
      appBar: AppBar(
        title: const Text("Музыка"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text(
              "Ereke AI генерирует идеи треков и тексты. "
              "Готовые данные можно загрузить в Suno / Udio / другие сервисы.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Опиши настроение или стиль трека...",
                hintStyle: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _generate,
              child: const Text("Сгенерировать музыку (идею)"),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  result,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// Вкладка "История"
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = HistoryStore.instance.history;

    return Scaffold(
      backgroundColor: const Color(0xFF050712),
      appBar: AppBar(
        title: const Text("История чатов"),
        centerTitle: true,
      ),
      body: history.isEmpty
          ? const Center(
              child: Text(
                "История пока пустая",
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: history.length,
              itemBuilder: (context, i) {
                final msg = history[i];
                final isUser = msg["role"] == "user";
                return ChatBubble(
                  text: msg["text"] ?? "",
                  isUser: isUser,
                );
              },
            ),
    );
  }
}

