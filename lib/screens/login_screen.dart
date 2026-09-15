import 'package:flax_app/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();

  final TextEditingController _usernameController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      if (!mounted) return;

      setState(() {
        _error = 'Please enter username and password.';
      });

      return;
    }

    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      debugPrint('Waiting for login');

      final result = await _api.login(
        username: username,
        password: password,
      );

      debugPrint('Login Complete: $result');

      final token = result['token']?.toString();
      final userValue = result['user'];

      if (token == null || token.isEmpty) {
        throw Exception(
          'Login response did not contain a token.',
        );
      }

      if (userValue is! Map) {
        throw Exception(
          'Login response did not contain user information.',
        );
      }

      final user = Map<String, dynamic>.from(userValue);

      await _auth.saveLogin(
        token: token,
        user: user,
      );

      if (!mounted) return;

      // LoginScreen will be replaced by DashboardScreen.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const DashboardScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FD),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(height: 20),
                const Text(
                  'Flax Availability Tracker',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to continue',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _usernameController,
                  enabled: !_loading,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    label: 'Username',
                    icon: Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  enabled: !_loading,
                  obscureText: _obscurePassword,
                  onSubmitted: (_) => _login(),
                  decoration: _inputDecoration(
                    label: 'Password',
                    icon: Icons.lock_outline,
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFECACA),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D5CFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFF1D5CFF),
          width: 1.5,
        ),
      ),
    );
  }
}
