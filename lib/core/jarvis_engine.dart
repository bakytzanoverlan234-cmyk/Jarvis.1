class JarvisEngine {
  bool active = false;

  bool wakeWord(String text) {
    if (text.toLowerCase().contains('брат') || text.toLowerCase().contains('братан')) {
      active = true;
      return true;
    }
    return false;
  }

  Future<String> respond(String input) async {
    if (!active) {
      return "Скажи 'брат', чтобы меня активировать.";
    }

    input = input.toLowerCase();

    if (input.contains("кто ты")) return "Я Jarvis, твой продвинутый ассистент.";
    if (input.contains("привет")) return "Привет, я готов работать.";
    if (input.contains("время")) return "Сейчас ${DateTime.now().hour}:${DateTime.now().minute}";
    if (input.contains("анекдот")) return "Мой код не тупой, он просто творческий.";

    return "Я анализирую: $input";
  }
}
