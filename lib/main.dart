// ================= EREKE AI : ГОЛОС + ПАНЕЛЬ РЕЖИМОВ ================= // ЗАМЕНИ ВЕСЬ lib/main.dart НА ЭТО

import 'package:flutter/material.dart'; import 'package:flutter_tts/flutter_tts.dart'; import 'package:speech_to_text/speech_to_text.dart' as stt; import 'package:shared_preferences/shared_preferences.dart'; import 'core/hybrid_ai.dart';

void main() => runApp(const ErekeAI());

class ErekeAI extends StatelessWidget { const ErekeAI({super.key});

@override Widget build(BuildContext context) { return const MaterialApp( debugShowCheckedModeBanner: false, home: MainScreen(), ); } }

// ================= MAIN SCREEN WITH MODES ================= class MainScreen extends StatefulWidget { const MainScreen({super.key});

@override State<MainScreen> createState() => _MainScreenState(); }

class _MainScreenState extends State<MainScreen> { int currentMode = 0;

final List<Widget> modes = const [ ChatScreen(), ImagesStubScreen(), MusicStubScreen(), ];

@override Widget build(BuildContext context) { return Scaffold( backgroundColor: const Color(0xFF0E0F1A), bottomNavigationBar: BottomNavigationBar( currentIndex: currentMode, backgroundColor: const Color(0xFF1A1B2F), selectedItemColor: Colors.cyanAccent, unselectedItemColor: Colors.white60, onTap: (i) => setState(() => currentMode = i), items: const [ BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Чат"), BottomNavigationBarItem(icon: Icon(Icons.image), label: "Картинки"), BottomNavigationBarItem(icon: Icon(Icons.music_note), label: "Музыка"), ], ), body: modes[currentMode], ); } }

// ================= CHAT SCREEN ================= class ChatScreen extends StatefulWidget { const ChatScreen({super.key});

@override State<ChatScreen> createState() => _ChatScreenState(); }

class _ChatScreenState extends State<ChatScreen> { final HybridAI ai = HybridAI(); final FlutterTts tts = FlutterTts(); final stt.SpeechToText speech = stt.SpeechToText(); final TextEditingController controller = TextEditingController();

List<Map<String, String>> messages = []; bool listening = false; bool voiceEnabled = true; String voiceGender = "female";

@override void initState() { super.initState(); _loadSettings(); }

Future<void> _loadSettings() async { final prefs = await SharedPreferences.getInstance(); voiceEnabled = prefs.getBool('voiceEnabled') ?? true; voiceGender = prefs.getString('voiceGender') ?? "female"; setState(() {}); _initTts(); }

Future<void> _saveSettings() async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('voiceEnabled', voiceEnabled); await prefs.setString('voiceGender', voiceGender); }

Future<void> _initTts() async { await tts.setLanguage("ru-RU"); await tts.setSpeechRate(0.45);

final voices = await tts.getVoices;
for (var v in voices) {
  if (voiceGender == "female" && v['name'].toLowerCase().contains("female")) {
    await tts.setVoice(Map<String, String>.from(v));
  }
  if (voiceGender == "male" && v['name'].toLowerCase().contains("male")) {
    await tts.setVoice(Map<String, String>.from(v));
  }
}

}

Future<void> _sendText(String text) async { if (text.trim().isEmpty) return; controller.clear();

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

void openSettings() { showModalBottomSheet( context: context, backgroundColor: const Color(0xFF1A1B2F), shape: const RoundedRectangleBorder( borderRadius: BorderRadius.vertical(top: Radius.circular(20)), ), builder: () => _buildSettingsPanel(), ); }

Widget _buildSettingsPanel() { return Padding( padding: const EdgeInsets.all(16), child: Column( mainAxisSize: MainAxisSize.min, children: [ const Text("Голосовые настройки", style: TextStyle(color: Colors.cyanAccent, fontSize: 18)),

SwitchListTile(
        title: const Text("Озвучка ответа",
            style: TextStyle(color: Colors.white)),
        value: voiceEnabled,
        onChanged: (v) {
          setState(() => voiceEnabled = v);
          _saveSettings();
