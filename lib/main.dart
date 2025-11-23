import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/hybrid_ai.dart';

// --------------------------------------------------
// Запуск приложения
// --------------------------------------------------
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
        fontFamily: 'Roboto',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050814),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF7C4DFF),
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

// --------------------------------------------------
// РЕЖИМЫ АССИСТЕНТА
// --------------------------------------------------

enum AssistantMode {
  chat,
  code,
  music,
  image,
  genius,
}

String modeTitle(AssistantMode m) {
  switch (m) {
    case AssistantMode.chat:
      return 'Чат';
    case AssistantMode.code:
      return 'Кодер';
    case AssistantMode.music:
      return 'Музыка';
    case AssistantMode.image:
      return 'Картинки';
    case AssistantMode.genius:
      return 'Джарвис';
  }
}

String modePrompt(AssistantMode m) {
  switch (m) {
    case AssistantMode.chat:
      return 'Отвечай как дружелюбный ассистент.';
    case AssistantMode.code:
      return 'Ты опытный программист. Пиши код и объяснения.';
    case AssistantMode.music:
      return 'Ты композитор. Пиши тексты песен, аккорды, структуру треков.';
    case AssistantMode.image:
      return 'Ты мастер промптов для генерации изображений. Пиши чёткие описания картинок.';
    case AssistantMode.genius:
      return 'Ты как Джарвис: умный, ироничный, стратегический ассистент.';
  }
}

// --------------------------------------------------
// ЭКРАН ЧАТА
// --------------------------------------------------

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

  List<Map<String, String>> messages = []; // {role: user/ai, text: ...}
  bool listening = false;
  bool typing = false;

  bool voiceEnabled = true;
  bool isSpeaking = false;
  String voiceGender = 'female'; // male/female
  double voiceRate = 0.45;

  AssistantMode currentMode = AssistantMode.chat;

  static const _historyKey = 'chat_history_v1';
  static const _voiceEnabledKey = 'voice_enabled';
  static const _voiceGenderKey = 'voice_gender';
  static const _voiceRateKey = 'voice_rate';

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadSettingsAndHistory();
  }

  // ----------------- ИНИЦИАЛИЗАЦИЯ -----------------

  Future<void> _initTts() async {
    await tts.setLanguage("ru-RU");
    await tts.setPitch(1.0);
    await tts.setSpeechRate(voiceRate);

    // выбор голоса по полу (это не всегда работает одинаково на всех устройствах,
    // но пробуем найти более подходящий вариант)
    final voices = await tts.getVoices;

    if (voices is List) {
      String target = voiceGender == 'male' ? 'male' : 'female';
      final match = voices.cast<Map>().firstWhere(
        (v) {
          final name = (v['name'] ?? '').toString().toLowerCase();
          final locale = (v['locale'] ?? '').toString().toLowerCase();
          return name.contains(target) || locale.contains('ru');
        },
        orElse: () => voices.first,
      );
      await tts.setVoice(match);
    }

    tts.setCompletionHandler(() {
      setState(() => isSpeaking = false);
    });
  }

  Future<void> _loadSettingsAndHistory() async {
    final prefs = await SharedPreferences.getInstance();

    voiceEnabled = prefs.getBool(_voiceEnabledKey) ?? true;
    voiceGender = prefs.getString(_voiceGenderKey) ?? 'female';
    voiceRate = prefs.getDouble(_voiceRateKey) ?? 0.45;

    final raw = prefs.getString(_historyKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        messages = decoded
            .map((e) => (e as Map).map(
                  (k, v) => MapEntry(k.toString(), v.toString()),
                ))
            .toList();
      } catch (_) {
        messages = [];
      }
    }

    setState(() {});
    await _initTts();
    _scrollToBottom();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(messages));
  }

  Future<void> _saveVoiceSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceEnabledKey, voiceEnabled);
    await prefs.setString(_voiceGenderKey, voiceGender);
    await prefs.setDouble(_voiceRateKey, voiceRate);
  }

  // ----------------- ОТПРАВКА ТЕКСТА -----------------

  Future<void> _sendText(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    controller.clear();
    await tts.stop();
    setState(() {
      messages.add({"role": "user", "text": cleaned});
      typing = true;
      isSpeaking = false;
    });
    _scrollToBottom();
    await _saveHistory();

    final modeInstruction = modePrompt(currentMode);
    final promptForAI = '$modeInstruction\n\nПользователь: $cleaned';

    final reply = await ai.respond(promptForAI);

    setState(() {
      messages.add({"role": "ai", "text": reply});
      typing = false;
    });
    _scrollToBottom();
    await _saveHistory();

    if (voiceEnabled) {
      await _speak(reply);
    }
  }

  // ----------------- РЕЧЬ -----------------

  String _prepareTextForVoice(String text) {
    // убираем разметку, звёздочки, код, лишние символы
    var t = text
        .replaceAll(RegExp(r'[*`_>#\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // ограничиваем длину, чтобы не читал километровый ответ
    const maxLen = 400;
    if (t.length > maxLen) {
      t = t.substring(0, maxLen) + '… (продолжение в чате)';
    }
    return t;
  }

  Future<void> _speak(String text) async {
    final toSay = _prepareTextForVoice(text);
    if (toSay.isEmpty) return;

    await tts.stop();
    setState(() => isSpeaking = true);
    await tts.setSpeechRate(voiceRate);
    await tts.speak(toSay);
  }

  Future<void> _stopSpeaking() async {
    await tts.stop();
    setState(() => isSpeaking = false);
  }

  // ----------------- ГОЛОСОВОЙ ВВОД -----------------

  Future<void> _startListening() async {
    final available = await speech.initialize();
    if (!available) return;

    setState(() => listening = true);

    speech.listen(onResult: (result) async {
      if (result.finalResult) {
        setState(() => listening = false);
        await speech.stop();
        await _sendText(result.recognizedWords);
      }
    });
  }

  // ----------------- ПРОЧЕЕ -----------------

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _clearChat() async {
    await _stopSpeaking();
    setState(() {
      messages.clear();
    });
    await ai.clearHistory();
    await _saveHistory();
  }

  void _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          voiceEnabled: voiceEnabled,
          voiceGender: voiceGender,
          voiceRate: voiceRate,
          onChanged: (enabled, gender, rate) async {
            setState(() {
              voiceEnabled = enabled;
              voiceGender = gender;
              voiceRate = rate;
            });
            await _saveVoiceSettings();
            await _initTts();
          },
        ),
      ),
    );
  }

  // ----------------- UI -----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050814),
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF00E5FF),
              child: Text(
                'E',
                style: TextStyle(
                  color: Color(0xFF050814),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Ereke AI',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Онлайн • персональный ассистент',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                )
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: voiceEnabled
                ? 'Отключить автоозвучку'
                : 'Включить автоозвучку',
            icon: Icon(
              voiceEnabled ? Icons.volume_up : Icons.volume_off,
              color: voiceEnabled ? Colors.cyanAccent : Colors.white60,
            ),
            onPressed: () async {
              setState(() => voiceEnabled = !voiceEnabled);
              await _saveVoiceSettings();
            },
          ),
          IconButton(
            tooltip: 'Очистить чат',
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearChat,
          ),
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Панель режимов
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: AssistantMode.values.map((mode) {
                final selected = mode == currentMode;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(modeTitle(mode)),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => currentMode = mode);
                    },
                    selectedColor: const Color(0xFF00E5FF),
                    backgroundColor: const Color(0xFF131628),
                    labelStyle: TextStyle(
                      color: selected ? Colors.black : Colors.white70,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 4),

          // Сообщения
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final msg = messages[i];
                final isUser = msg['role'] == 'user';
                return _buildBubble(msg['text'] ?? '', isUser);
              },
            ),
          ),

          if (typing)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Ereke AI печатает…',
                style: TextStyle(color: Colors.cyanAccent),
              ),
            ),

          // Нижняя панель ввода
          SafeArea(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF090C1A),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121528),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Напиши Ereke AI…',
                          hintStyle: TextStyle(color: Colors.white54),
                        ),
                        onSubmitted: _sendText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Кнопка микрофона / стоп-аудио
                  GestureDetector(
                    onTap: () {
                      if (isSpeaking) {
                        _stopSpeaking();
                      } else if (!listening) {
                        _startListening();
                      } else {
                        speech.stop();
                        setState(() => listening = false);
                      }
                    },
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: listening || isSpeaking
                          ? Colors.redAccent
                          : const Color(0xFF00E5FF),
                      child: Icon(
                        listening || isSpeaking ? Icons.stop : Icons.mic,
                        color: const Color(0xFF050814),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Кнопка отправки
                  GestureDetector(
                    onTap: () => _sendText(controller.text),
                    child: const CircleAvatar(
                      radius: 22,
                      backgroundColor: Color(0xFF00E5FF),
                      child: Icon(
                        Icons.send,
                        color: Color(0xFF050814),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(String text, bool isUser) {
    final bg = isUser
        ? const Color(0xFF00BCD4)
        : const Color(0xFF181B2F);
    final textColor = isUser ? Colors.black : Colors.white;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(color: textColor, fontSize: 15),
        ),
      ),
    );
  }
}

// --------------------------------------------------
// ЭКРАН НАСТРОЕК
// --------------------------------------------------

class SettingsScreen extends StatefulWidget {
  final bool voiceEnabled;
  final String voiceGender;
  final double voiceRate;
  final void Function(bool enabled, String gender, double rate) onChanged;

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

  void _apply() {
    widget.onChanged(_voiceEnabled, _voiceGender, _voiceRate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050814),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050814),
        title: const Text('Настройки Ereke AI'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Автоозвучка ответов'),
            value: _voiceEnabled,
            onChanged: (v) {
              setState(() => _voiceEnabled = v);
              _apply();
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Голос',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Женский'),
                selected: _voiceGender == 'female',
                onSelected: (_) {
                  setState(() => _voiceGender = 'female');
                  _apply();
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Мужской'),
                selected: _voiceGender == 'male',
                onSelected: (_) {
                  setState(() => _voiceGender = 'male');
                  _apply();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Скорость речи',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _voiceRate,
            min: 0.3,
            max: 0.9,
            divisions: 12,
            label: _voiceRate.toStringAsFixed(2),
            onChanged: (v) {
              setState(() => _voiceRate = v);
              _apply();
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Музыка и картинки',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Сейчас Ereke AI генерирует тексты песен, аккорды и промпты '
            'для изображений. Для реальной генерации аудио и картинок '
            'нужно подключить отдельные API (Suno,
            Stable Audio, DALL·E и т.п.).',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

