import 'dart:math';

class MusicEngine {
  final List<String> moods = [
    "Lo-fi chill бит",
    "Эпичная оркестровая тема",
    "Киберпанк синтвейв",
    "Расслабляющий эмбиент",
    "Хип-хоп бит",
    "Тёмный техно-трек",
    "Музыка для концентрации"
  ];

  String generateMusicDescription({String? style}) {
    final random = Random();
    String mood = style ?? moods[random.nextInt(moods.length)];

    return "🎵 Музыка создана\nСтиль: $mood\n(В будущих версиях будет реальный аудиофайл)";
  }
}
