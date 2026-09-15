import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _auth = AuthService();

  bool _checkingLogin = true;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    try {
      final loggedIn = await _auth.isLoggedIn();

      if (!mounted) return;

      if (loggedIn) {
        _openDashboard();
      } else {
        _openLogin();
      }
    } catch (e) {
      if (!mounted) return;

      _openLogin();
    }
  }

  void _openLogin() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  void _openDashboard() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const DashboardScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FD),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.view_module_outlined,
                size: 32,
                color: Color(0xFF1D5CFF),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Flax Availability Tracker',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}