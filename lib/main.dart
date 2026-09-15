import 'package:flax_app/screens/dashboard_screen.dart';
import 'package:flax_app/screens/home_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const FlaxApp());
}

class FlaxApp extends StatelessWidget {
  const FlaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flax Tracker',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
