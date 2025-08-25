import 'package:flutter/material.dart';
import 'package:flutter_sample_networking/ui/screens/data_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Networking Sample',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const DataScreen(),
    );
  }
}
