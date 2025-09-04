import 'package:flutter/material.dart';
import 'package:flutter_sample_networking/ui/screens/data_screen.dart';
import 'package:flutter_sample_networking/ui/screens/bench_screen.dart';

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
      home: const RootTabs(),
    );
  }
}

class RootTabs extends StatefulWidget {
  const RootTabs({super.key});

  @override
  State<RootTabs> createState() => _RootTabsState();
}

class _RootTabsState extends State<RootTabs> {
  int _currentIndex = 0;

  final _screens = const [
    BenchScreen(),
    DataScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.speed),
            label: 'Bench',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.data_usage),
            label: 'Data',
          ),
        ],
      ),
    );
  }
}
