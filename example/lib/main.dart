import 'package:flutter/material.dart';
import 'inpainting_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Magic Eraser Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const InpaintingPage(),
    );
  }
}
