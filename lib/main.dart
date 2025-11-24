import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'core/hybrid_ai.dart';

typedef VoiceSettingsChanged = void Function(
  bool enabled,
  String gender,
  double rate,
);

void main() {
  runApp(const ErekeAIApp());
}

class ErekeAIApp extends StatelessWidget {
  const ErekeAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ereke AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050914),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF050914),
          elevation: 0,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  bool voiceEnabled = true;
  String voiceGender = 'female';
  double voiceRate = 0.45;

  void _updateVoiceSettings(bool enabled, String gender, double rate) {
    setState(() {
      voiceEnabled = enabled;
      voiceGender = gender;
      voiceRate = rate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ChatScreen(
        voiceEnabled: voiceEnabled,
        voiceGender: voiceGender,
        voiceRate: voiceRate,
        onVoiceSettingsChanged: _updateVoiceSettings,
      ),
      const ImagesScreen(),
      const MusicScreen(),
      SettingsScreen(
        voiceEnabled: voiceEnabled,
        voiceGender: voiceGender,
        voiceRate: voiceRate,
        onChanged: _updateVoiceSettings,
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF050914),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: const Color(0xFF050914),
          selectedItemColor: Colors.cyanAccent,
          unselectedItemColor: Colors.white60,
          type: BottomNavigationBarType.fixed,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Чат',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.image_outlined),
              activeIcon: Icon(Icons.image),
              label: 'Картинки',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.music_note_outlined),
              activeIcon: Icon(Icons.music_note),
              label: 'Музыка',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Настройки',
            ),
          ],
        ),
      ),
    );
  }
}
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.voiceEnabled,
    required this.voiceGender,
    required this.voiceRate,
    required this.onVoiceSettingsChanged,
  });

  final bool voiceEnabled;
  final String voiceGender;
  final double voiceRate;
  final VoiceSettingsChanged onVoiceSettingsChanged;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final HybridAI ai = HybridAI();
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();
  final TextEditingController controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> messages = [];

  bool _listening = false;
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voiceGender != widget.voiceGender ||
        oldWidget.voiceRate != widget.voiceRate) {
      _initTts();
    }
  }

  Future<void> _initTts() async {
    await tts.setLanguage('ru-RU');
    await tts.setSpeechRate(widget.voiceRate.clamp(0.2, 0.9));
    // Немного меняем pitch под выбранный пол
    if (widget.voiceGender == 'male') {
      await tts.setPitch(0.9);
    } else {
      await tts.setPitch(1.1);
    }
  }

  Future<void> _sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    controller.clear();
    setState(() {
      messages.add({'role': 'user', 'text': trimmed});
      _typing = true;
    });
    _scrollToBottom();

    final reply = await ai.respond(trimmed);

    setState(() {
      messages.add({'role': 'ai', 'text': reply});
      _typing = false;
    });
    _scrollToBottom();

    if (widget.voiceEnabled) {
      await tts.stop();
      await tts.speak(reply);
    }
  }
void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _startListening() async {
    final available = await speech.initialize();
    if (!available) return;

    setState(() => _listening = true);

    speech.listen(onResult: (result) {
      if (!mounted) return;
      if (result.finalResult) {
        setState(() => _listening = false);
        speech.stop();
        _sendText(result.recognizedWords);
      }
    });
  }

  Future<void> _stopListening() async {
    await speech.stop();
    setState(() => _listening = false);
  }

  void _clearChat() {
    setState(() {
      messages.clear();
    });
    ai.clearHistory();
    tts.stop();
  }

  void _openSettings() {
    widget.onVoiceSettingsChanged(
      widget.voiceEnabled,
      widget.voiceGender,
      widget.voiceRate,
    );
    // Переключение на вкладку "Настройки" через нижнее меню (MainScreen).
  }

  @override
  void dispose() {
    controller.dispose();
    _scrollController.dispose();
    tts.stop();
    tts.stop();
    speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050914),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                ),
              ),
              child: const Center(
                child: Text(
                  'E',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Ereke AI',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Онлайн • персональный ассистент',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.voiceEnabled ? Icons.volume_up : Icons.volume_off,
              color: widget.voiceEnabled ? Colors.cyanAccent : Colors.white60,
            ),
            tooltip: widget.voiceEnabled
                ? 'Отключить озвучку'
                : 'Включить озвучку',
            onPressed: () {
              widget.onVoiceSettingsChanged(
                !widget.voiceEnabled,
                widget.voiceGender,
                widget.voiceRate,
              );
            },
          ),
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
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isUser = msg['role'] == 'user';
                return _ChatBubble(
                  text: msg['text'] ?? '',
                  isUser: isUser,
                );
              },
            ),
          ),
          if (_typing)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'Ereke AI печатает...',
                style: TextStyle(color: Colors.cyanAccent),
              ),
            ),
          _buildInputBar(),
        ],
      ),
    );
  }
Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF060A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111627),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Напиши Ereke AI...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onSubmitted: _sendText,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _sendText(controller.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.send, color: Colors.black),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _listening ? _stopListening : _startListening,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _listening ? Colors.redAccent : Colors.tealAccent,
              ),
              child: Icon(
                _listening ? Icons.stop : Icons.mic,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final alignment =
        isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bgColor = isUser
        ? const Color(0xFF00B0FF)
        : const Color(0xFF111827);
    final textColor = isUser ? Colors.black : Colors.white;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
class ImagesScreen extends StatelessWidget {
  const ImagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF050914),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Режим картинок скоро будет подключён через HF_API_KEY и CLIPDROP_API_KEY.\n'
            'Сейчас доступен только интеллектуальный чат.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF050914),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Музыкальный режим будет подключён через Suno / другие сервисы.\n'
            'Пока можно генерировать тексты песен и аккорды прямо в чате.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.voiceEnabled,
    required this.voiceGender,
    required this.voiceRate,
    required this.onChanged,
  });

  final bool voiceEnabled;
  final String voiceGender;
  final double voiceRate;
  final VoiceSettingsChanged onChanged;

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
      backgroundColor: const Color(0xFF050914),
      appBar: AppBar(
        title: const Text('Настройки Ereke AI'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Голосовой ассистент',
            style: TextStyle(
              color: Colors.cyanAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text(
              'Включить озвучку',
              style: TextStyle(color: Colors.white),
            ),
            value: _voiceEnabled,
            onChanged: (v) {
              setState(() => _voiceEnabled = v);
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Пол голоса',
            style: TextStyle(
              color: Colors.cyanAccent,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              ChoiceChip(
                label: const Text('Женский'),
                selected: _voiceGender == 'female',
                onSelected: (_) {
                  setState(() => _voiceGender = 'female');
                },
              ),
              ChoiceChip(
                label: const Text('Мужской'),
                selected: _voiceGender == 'male',
                onSelected: (_) {
                  setState(() => _voiceGender = 'male');
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Скорость речи',
            style: TextStyle(
              color: Colors.cyanAccent,
              fontSize: 16,
            ),
          ),
          Slider(
            min: 0.2,
            max: 0.9,
            value: _voiceRate,
            onChanged: (v) {
              setState(() => _voiceRate = v);
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              widget.onChanged(
                _voiceEnabled,
                _voiceGender,
                _voiceRate,
              );
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Пока Ereke AI работает как интеллектуальный чат.\n'
            'Поддержка реальной генерации музыки и изображений будет добавлена позже через внешние API (HF_API_KEY, CLIPDROP_API_KEY, Suno и др.).',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

