import 'package:flutter/material.dart';

void main() {
  runApp(const JarvisApp());
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Jarvis запущен',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}
// rebuild trigger
