import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  Future<void> saveLogin({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _tokenKey,
      token,
    );

    await prefs.setString(
      _userKey,
      jsonEncode(user),
    );
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_tokenKey);
  }

  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();

    final value = prefs.getString(_userKey);

    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    return null;
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();

    return token != null && token.isNotEmpty;
  }

  Future<String> getUserName() async {
    final user = await getUser();

    if (user == null) {
      return '';
    }

    return user['name']?.toString() ??
        user['username']?.toString() ??
        '';
  }

  Future<String> getRole() async {
    final user = await getUser();

    if (user == null) {
      return '';
    }

    return user['role']?.toString() ?? 'user';
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}