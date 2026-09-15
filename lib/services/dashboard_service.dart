import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DashboardService {
  static const String baseUrl =
      'https://flax-tracker-backend.onrender.com/api';

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('auth_token');

    if (token == null || token.trim().isEmpty) {
      return null;
    }

    return token.trim();
  }

  /// Headers for authenticated dashboard requests.
  Future<Map<String, String>> _authHeaders() async {
    final token = await _getAuthToken();

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Token $token';
    }

    return headers;
  }

  // ============================================================
  // DASHBOARD SUMMARY
  // ============================================================

  Future<Map<String, dynamic>> getSummary() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/dashboard/summary/',
      ),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load dashboard summary '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'Invalid dashboard summary response.',
      );
    }

    return data;
  }

  // ============================================================
  // DASHBOARD OVERVIEW
  // ============================================================

  Future<Map<String, dynamic>> getOverview() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/dashboard/overview/',
      ),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load dashboard overview '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'Invalid dashboard overview response.',
      );
    }

    return data;
  }

  // ============================================================
  // DASHBOARD STATUS
  // ============================================================

  Future<Map<String, dynamic>> getStatus() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/dashboard/status/',
      ),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load dashboard status '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'Invalid dashboard status response.',
      );
    }

    return data;
  }

  // ============================================================
  // RECENT ASSIGNMENTS
  // ============================================================

  Future<List<dynamic>> getRecentAssignments() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/dashboard/recent-assignments/',
      ),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load recent assignments '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! List) {
      throw Exception(
        'Invalid recent assignments response.',
      );
    }

    return data;
  }

  // ============================================================
  // RECENT ACTIVITY
  // ============================================================

  Future<List<dynamic>> getRecentActivity() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/dashboard/recent-activity/',
      ),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load recent activity '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! List) {
      throw Exception(
        'Invalid recent activity response.',
      );
    }

    return data;
  }

  // ============================================================
  // TOP DESIGN USAGE
  // ============================================================

  Future<List<dynamic>> getTopDesignUsage() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/dashboard/top-design-usage/',
      ),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load design usage '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! List) {
      throw Exception(
        'Invalid design usage response.',
      );
    }

    return data;
  }
}