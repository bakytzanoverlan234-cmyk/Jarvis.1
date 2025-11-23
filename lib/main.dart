import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'core/hybrid_ai.dart';

void main() => runApp(const ErekeAIApp());

/// Корневое приложение
class ErekeAIApp extends StatelessWidget {
  const ErekeAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ereke AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050814),
        primaryColor: const Color(0xFF00E5FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF7C4DFF),
          surface: Color(0xFF101324),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

/// Модель сообщения
class ChatMessage {
  final String text;
  final bool fromUser;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.fromUser,
    required this.time,
  });
}

/// Основной экран чата
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

  final List<ChatMessage> messages = [];

  bool listening = false;
  bool typing = false;

  // Настройки ассистента
  bool voiceEnabled = true;
  String selectedVoice = 'female'; // 'male' / 'female'
  double speechRate = 0.45;
  bool hapticsOn = true;
  bool inAppNotifyOn = true;

  @override
  void initState() {
    super.initState();
    _initTts();
    _addWelcomeMessage();
  }

  Future<void> _initTts() async {
    await tts.setLanguage("ru-RU");
    await tts.setSpeechRate(speechRate);
    await _applyVoice();
  }

  Future<void> _applyVoice() async {
    // Пытаемся подобрать адекватный голос под русский
    // Если таких нет, система выберет ближайший.
    if (selectedVoice == 'female') {
      await tts.setVoice({
        "name": "ru-ru-x-ruf-local",
        "locale": "ru-RU",
      });
    } else {
      await tts.setVoice({
        "name": "ru-ru-x-rud-local",
        "locale": "ru-RU",
      });
    }
  }

  void _addWelcomeMessage() {
    messages.add(
      ChatMessage(
        text: "Здравствуйте! Я Ereke AI. Чем могу помочь сегодня?",
        fromUser: false,
        time: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    tts.stop();
    controller.dispose();
    _scroll.dispose();
    speech.stop();
    super.dispose();
  }

  String _cleanForSpeech(String text) {
    // Убираем лишние знаки, чтобы речь звучала естественнее
    return text
        .replaceAll(RegExp(r'[•\-•]+'), ' ')
        .replaceAll(RegExp(r'[\[\]\(\)\*\_\#\~\`\|]'), '')
        .replaceAll(RegExp(r'[!?]+'), '.')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _speak(String text) async {
    if (!voiceEnabled) return;
    final cleaned = _cleanForSpeech(text);
    if (cleaned.isEmpty) return;
    await tts.stop();
    await tts.speak(cleaned);
  }

  Future<void> _sendText(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;

    controller.clear();

    setState(() {
      messages.add(ChatMessage(
        text: text,
        fromUser: true,
        time: DateTime.now(),
      ));
      typing = true;
    });
    _scrollToBottom();

    try {
      final reply = await ai.respond(text);

      setState(() {
        messages.add(ChatMessage(
          text: reply,
          fromUser: false,
          time: DateTime.now(),
        ));
        typing = false;
      });
      _scrollToBottom();

      if (inAppNotifyOn && !voiceEnabled && hapticsOn) {
        HapticFeedback.lightImpact();
      }

      await _speak(reply);
    } catch (e) {
      setState(() {
        typing = false;
        messages.add(ChatMessage(
          text: "Ошибка ассистента: $e",
          fromUser: false,
          time: DateTime.now(),
        ));
      });
      _scrollToBottom();
    }
  }

  Future<void> _startListening() async {
    final available = await speech.initialize();
    if (!available) return;

    if (hapticsOn) HapticFeedback.mediumImpact();

    setState(() => listening = true);

    speech.listen(onResult: (result) {
      if (result.finalResult) {
        final heard = result.recognizedWords;
        setState(() => listening = false);
        speech.stop();
        _sendText(heard);
      }
    });
  }

  void _stopListening() {
    speech.stop();
    setState(() => listening = false);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      messages.clear();
      ai.clearHistory();
      _addWelcomeMessage();
    });
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101324),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const Text(
                  "Настройки Ereke AI",
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Голосовая озвучка
                SwitchListTile(
                  value: voiceEnabled,
                  onChanged: (v) {
                    setState(() => voiceEnabled = v);
                  },
                  activeColor: Colors.cyanAccent,
                  title: const Text(
                    "Голосовая озвучка",
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    "Включить или выключить озвучивание ответов",
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),

                // Выбор голоса
                ListTile(
                  title: const Text(
                    "Голос",
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    selectedVoice == 'female'
                        ? "Женский голос"
                        : "Мужской голос",
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  trailing: DropdownButton<String>(
                    value: selectedVoice,
                    dropdownColor: const Color(0xFF101324),
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: 'female',
                        child: Text(
                          "Женский",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'male',
                        child: Text(
                          "Мужской",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => selectedVoice = value);
                      await _applyVoice();
                    },
                  ),
                ),

                // Скорость речи
                ListTile(
                  title: const Text(
                    "Скорость речи",
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Slider(
                    value: speechRate,
                    min: 0.2,
                    max: 0.8,
                    divisions: 6,
                    activeColor: Colors.cyanAccent,
                    label: speechRate.toStringAsFixed(2),
                    onChanged: (v) async {
                      setState(() => speechRate = v);
                      await tts.setSpeechRate(v);
                    },
                  ),
                ),

                const Divider(color: Colors.white24),

                // Вибро и "уведомления"
                SwitchListTile(
                  value: hapticsOn,
                  onChanged: (v) {
                    setState(() => hapticsOn = v);
                  },
                  activeColor: Colors.cyanAccent,
                  title: const Text(
                    "Вибро / Haptic",
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    "Лёгкая вибрация при действиях",
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
                SwitchListTile(
                  value: inAppNotifyOn,
                  onChanged: (v) {
                    setState(() => inAppNotifyOn = v);
                  },
                  activeColor: Colors.cyanAccent,
                  title: const Text(
                    "Внутренние уведомления",
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    "Лёгкий отклик при новых ответах",
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),

                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "Готово",
                      style: TextStyle(color: Colors.cyanAccent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Фон в стиле Джарвиса
          const _JarvisBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 8),
                Expanded(child: _buildMessagesList()),
                if (typing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: TypingIndicator(),
                  ),
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          // Аватар Ereke AI
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(0.5),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                "E",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Ereke AI",
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                    SizedBox(width: 4),
                    Text(
                      "Онлайн • персональный ассистент",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: _clearChat,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.cyanAccent),
            onPressed: _openSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.fromUser;

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        gradient: isUser
            ? const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF18FFFF)],
              )
            : const LinearGradient(
                colors: [Color(0xFF181B32), Color(0xFF101324)],
              ),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: isUser
                ? Colors.cyanAccent.withOpacity(0.35)
                : Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        msg.text,
        style: TextStyle(
          color: isUser ? Colors.black : Colors.white,
          fontSize: 15.5,
          height: 1.35,
        ),
      ),
    );

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: bubble,
      );
    } else {
      // Сообщение ассистента с аватаркой слева
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 4),
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
              ),
            ),
            child: const Center(
              child: Text(
                "E",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: bubble),
        ],
      );
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF050814),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          // Кнопка микрофона
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: listening
                    ? const [Color(0xFFFF5252), Color(0xFFFF8A80)]
                    : const [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: listening
                      ? Colors.redAccent.withOpacity(0.7)
                      : Colors.cyanAccent.withOpacity(0.5),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                listening ? Icons.stop : Icons.mic,
                color: Colors.black,
              ),
              onPressed: listening ? _stopListening : _startListening,
            ),
          ),
          const SizedBox(width: 8),
          // Поле ввода
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF101324),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Напиши Ereke AI...",
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                minLines: 1,
                maxLines: 4,
                onSubmitted: _sendText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Кнопка отправки
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF18FFFF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(0.6),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black),
              onPressed: () => _sendText(controller.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Фон с неоновой "джарвис" графикой
class _JarvisBackground extends StatelessWidget {
  const _JarvisBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF02030A), Color(0xFF050814)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: _glowCircle(160, Colors.cyanAccent.withOpacity(0.22)),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: _glowCircle(220, const Color(0xFF7C4DFF).withOpacity(0.22)),
          ),
          Positioned(
            top: 180,
            left: -40,
            child: _glowCircle(120, Colors.blue.withOpacity(0.16)),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}

/// Анимация "печатает..."
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = _controller.value;

          double dotOpacity(int index) {
            final offset = (value + index * 0.2) % 1.0;
            if (offset < 0.3) {
              return 0.3 + offset * 2.0;
            } else if (offset < 0.8) {
              return 1.0;
            } else {
              return 1.0 - (offset - 0.8) * 5.0;
            }
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              return Opacity(
                opacity: dotOpacity(i).clamp(0.2, 1.0),
                child: Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.cyanAccent,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

