import 'dart:convert';

import 'package:flax_app/models/activity_log.dart';
import 'package:flax_app/models/assignment_history_entry.dart';
import 'package:flax_app/models/tree.dart';
import 'package:flax_app/models/tree_module_row.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax_app/models/app_user.dart';
import '../models/flax.dart';

class ApiService {
  static const String baseUrl = 'https://flax-tracker-backend.onrender.com/api';
  // static const String baseUrl = 'http://192.168.1.183:8000/api';

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
  Future<dynamic> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login/'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'password': password
      }),
    );

    dynamic body;

    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = null;
    }

    // 1. Guard against generic non-200 failure statuses safely
    if (response.statusCode != 200) {
      if (body is Map && body['detail'] != null) {
        throw Exception(body['detail'].toString());
      }
      throw Exception(
        body is Map && body['error'] != null
            ? body['error'].toString()
            : 'Login failed (${response.statusCode}).',
      );
    }

    // 2. Explicitly validate the body type structure before reading keys
    if (body == null || body is! Map<String, dynamic>) {
      throw Exception(
        'Server returned a 200 success code but an invalid or empty payload data body.',
      );
    }

    // 3. Verify that the token key actually exists in the map layout
    if (body['token'] == null) {
      throw Exception('Authentication token missing from server response map.');
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'auth_token',
      body['token'].toString(),
    );

    if (body['user'] is Map<String, dynamic>) {
      await prefs.setString(
        'auth_user',
        jsonEncode(body['user']),
      );
    }

    // =========================================================================
    // CRITICAL FIX: Return the parsed response body so AuthProvider can read it!
    // =========================================================================
    return body;
  }


  Future<Map<String, dynamic>> fetchCurrentUser() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me/'),
      headers: await _authHeaders(),
    );

    dynamic body;

    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = null;
    }

    if (response.statusCode != 200) {
      throw Exception(
        body is Map && body['detail'] != null
            ? body['detail'].toString()
            : 'Failed to load current user (${response.statusCode}).',
      );
    }

    if (body is! Map<String, dynamic>) {
      throw Exception('Invalid current user response from server.');
    }

    return body;
  }

  // ============================================================
  // FLAX - LIST
  // ============================================================

  Future<List<Flax>> fetchAllFlaxes({
    String? assignmentStatus,
    String? search,
    String? size,
    String? treeNo,
  }) async {
    final params = <String, String>{};

    if (assignmentStatus != null && assignmentStatus.trim().isNotEmpty) {
      params['assignment_status'] = assignmentStatus.trim();
    }

    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }

    if (size != null && size.trim().isNotEmpty) {
      params['size'] = size.trim();
    }

    if (treeNo != null && treeNo.trim().isNotEmpty) {
      params['tree_no'] = treeNo.trim();
    }

    String url = '$baseUrl/flaxes/';

    if (params.isNotEmpty) {
      final query = params.entries
          .map(
            (entry) =>
                '${Uri.encodeQueryComponent(entry.key)}='
                '${Uri.encodeQueryComponent(entry.value)}',
          )
          .join('&');

      url = '$url?$query';
    }

    final List<Flax> allFlaxes = [];

    while (url.isNotEmpty) {
      final response = await http.get(
        Uri.parse(url),
        headers: await _authHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load flaxes '
          '(${response.statusCode}): ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is List) {
        for (final item in decoded) {
          allFlaxes.add(
            Flax.fromJson(item as Map<String, dynamic>),
          );
        }
        url = '';
        continue;
      }

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid flax response.');
      }

      final results = decoded['results'] as List? ?? [];

      for (final item in results) {
        allFlaxes.add(
          Flax.fromJson(item as Map<String, dynamic>),
        );
      }

      final next = decoded['next'];

      if (next == null || next.toString().trim().isEmpty) {
        url = '';
      } else {
        url = next.toString();
      }
    }

    return allFlaxes;
  }

  Future<FlaxPage> fetchFlaxesPage({
    String? url,
  }) async {
    final targetUrl = url ?? '$baseUrl/flaxes/';

    final response = await http.get(
      Uri.parse(targetUrl),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load flaxes '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return FlaxPage.fromJson(data);
  }

  Future<List<Flax>> fetchFlaxes({
    FlaxAssignmentStatus? filter,
  }) async {
    final uri = Uri.parse('$baseUrl/flaxes/').replace(
      queryParameters: filter != null
          ? {
              'status': filter.apiValue,
            }
          : null,
    );

    final response = await http.get(
      uri,
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load flaxes '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body);

    final List results = body is Map ? (body['results'] ?? []) : body;

    return results
        .map(
          (e) => Flax.fromJson(
            e as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  // ============================================================
  // FLAX - CREATE
  // ============================================================

  Future<Flax> createFlax(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/flaxes/'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Failed to create flax '
        '(${response.statusCode}): ${response.body}',
      );
    }

    return Flax.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ============================================================
  // FLAX - UPDATE
  // ============================================================

  Future<Flax> updateFlax(
    String flaxNo,
    Map<String, dynamic> data,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/flaxes/$flaxNo/'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update flax '
        '(${response.statusCode}): ${response.body}',
      );
    }

    return Flax.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ============================================================
  // FLAX - DELETE
  // ============================================================

  Future<void> deleteFlax(
    String flaxId,
  ) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/flaxes/$flaxId/'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 204) {
      throw Exception(
        'Failed to delete flax '
        '(${response.statusCode}): ${response.body}',
      );
    }
  }

  // ============================================================
  // FLAX - ASSIGNMENT STATUS
  // ============================================================

  Future<Flax> setAssignmentStatus(
    String flaxNo,
    FlaxAssignmentStatus status, {
    String remarks = '',
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/flaxes/$flaxNo/set-status/'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'assignment_status': status.apiValue,
        'remarks': remarks,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update status '
        '(${response.statusCode}): ${response.body}',
      );
    }

    return Flax.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Flax> assignToTree(
    String flaxNo, {
    required String treeNo,
    String treeId = '',
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/flaxes/$flaxNo/assign/'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'tree_no': treeNo,
        'tree_id': treeId,
      }),
    );

    if (response.statusCode != 200) {
      String message =
          'Failed to assign flax (${response.statusCode})';

      try {
        final body = jsonDecode(response.body);

        if (body is Map) {
          message =
              body['error']?.toString() ??
              body['detail']?.toString() ??
              message;
        }
      } catch (_) {}

      throw Exception(message);
    }

    return Flax.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Flax> releaseFlax(
    String flaxNo,
  ) async {
    final uri = Uri.parse(
      '$baseUrl/flaxes/$flaxNo/release/',
    );

    final response = await http.patch(
      uri,
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to release flax '
        '(${response.statusCode}): ${response.body}',
      );
    }

    return Flax.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Release a flax together with its Top/Bottom Tunch Report readings
  /// and one or more casting images, in a single multipart request.
  ///
  /// Hits the SAME endpoint as `releaseFlax` (`PATCH /flaxes/<no>/release/`)
  /// but as multipart/form-data instead of JSON, since it now also
  /// carries file uploads. The backend's release view needs to be
  /// updated to parse `request.data` (works for both JSON and
  /// multipart under DRF) and to accept `top_tunch_report`,
  /// `bottom_tunch_report`, and one or more files under `images`.
  ///
  /// Web + Android/iOS compatible — do NOT use MultipartFile.fromPath(),
  /// it depends on dart:io and fails on Flutter Web (see
  /// uploadTreeModuleImages() above for the same reasoning).
  Future<Flax> releaseFlaxWithReport(
    String flaxNo, {
    required String topTunchReport,
    required String bottomTunchReport,
    required List<XFile> images,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/flaxes/$flaxNo/release/',
    );

    final request = http.MultipartRequest(
      'PATCH',
      uri,
    );

    final token = await _getAuthToken();

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Token $token';
    }

    request.fields['top_tunch_report'] = topTunchReport;
    request.fields['bottom_tunch_report'] = bottomTunchReport;

    for (final image in images) {
      final bytes = await image.readAsBytes();

      if (bytes.isEmpty) {
        continue;
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'images',
          bytes,
          filename: image.name,
        ),
      );
    }

    if (request.files.isEmpty) {
      throw Exception('No valid image data was selected.');
    }

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(
      streamedResponse,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to release flax '
        '(${response.statusCode}): ${response.body}',
      );
    }

    return Flax.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Flax> removeAssignment(
    String flaxNo,
    String confirmationCode,
  ) async {
    final response = await http.delete(
      Uri.parse(
        '$baseUrl/flaxes/$flaxNo/remove-assignment/',
      ),
      headers: await _authHeaders(),
      body: jsonEncode({
        'confirmation_code': confirmationCode,
      }),
    );

    if (response.statusCode != 200) {
      String message = 'Failed to remove assignment';

      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['error']?.toString() ?? message;
      } catch (_) {}

      throw Exception(
        '$message (${response.statusCode})',
      );
    }

    return Flax.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ============================================================
  // LEGACY STATUS METHODS
  // ============================================================

  Future<Flax> toggleStatus(
    String flaxId,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/flaxes/$flaxId/toggle_status/'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to toggle status '
        '(${response.statusCode}): ${response.body}',
      );
    }

    return Flax.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Flax> setStatus(
    String flaxId,
    FlaxAssignmentStatus status,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/flaxes/$flaxId/set_status/'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'status': status.apiValue,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to set status '
        '(${response.statusCode}): ${response.body}',
      );
    }

    return Flax.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> toggleCondition(
    String flaxNo,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/flaxes/$flaxNo/toggle-condition/'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to toggle condition '
        '(${response.statusCode}): ${response.body}',
      );
    }
  }

  // ============================================================
  // TREES
  // ============================================================

  Future<List<Tree>> fetchTrees({
    String search = '',
  }) async {
    final query = search.isNotEmpty
        ? '?search=${Uri.encodeQueryComponent(search)}'
        : '';

    final response = await http.get(
      Uri.parse('$baseUrl/trees/$query'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load trees '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    final List results = data is Map ? (data['results'] ?? []) : data;

    return results
        .map(
          (e) => Tree.fromJson(
            e as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  // ============================================================
  // ACTIVITY
  // ============================================================

  Future<List<ActivityLogEntry>> fetchRecentAssignments() async {
    final response = await http.get(
      Uri.parse('$baseUrl/activity/'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load activity '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final results = data['results'] as List? ?? [];

    return results
        .map(
          (e) => ActivityLogEntry.fromJson(
            e as Map<String, dynamic>,
          ),
        )
        .where(
          (entry) => entry.activityType == 'FLAX_ASSIGNED',
        )
        .toList();
  }

  // ============================================================
  // REPORTS
  // ============================================================

  Future<Map<String, dynamic>> fetchFlaxAssignmentReport({
    required String period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, String>{
      'period': period,
    };

    if (period == 'selected') {
      if (startDate == null || endDate == null) {
        throw Exception(
          'Start date and end date are required '
          'for a selected report.',
        );
      }

      String formatDate(DateTime date) {
        final month = date.month.toString().padLeft(2, '0');
        final day = date.day.toString().padLeft(2, '0');

        return '${date.year}-$month-$day';
      }

      query['start_date'] = formatDate(startDate);
      query['end_date'] = formatDate(endDate);
    }

    final uri = Uri.parse(
      '$baseUrl/reports/flax-assignment/',
    ).replace(
      queryParameters: query,
    );

    final response = await http.get(
      uri,
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load flax assignment report '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid report response from server.');
    }

    return decoded;
  }

  // ============================================================
  // TREE MODULE
  // ============================================================

  Future<int> submitTreeModuleBatch(
    List<TreeModuleRow> rows,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tree-module-batches/'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'details': rows.map((r) => r.toJson()).toList(),
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Failed to submit batch '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final id = data['id'];

    if (id is int) {
      return id;
    }

    if (id is String) {
      final parsed = int.tryParse(id);

      if (parsed != null) {
        return parsed;
      }
    }

    throw Exception('Server did not return a valid batch id.');
  }

  /// Web + Android/iOS compatible image upload.
  ///
  /// IMPORTANT:
  /// Do NOT use MultipartFile.fromPath() here.
  /// fromPath() depends on dart:io and fails on Flutter Web.
  Future<void> uploadTreeModuleImages(
    int batchId,
    List<XFile> images,
  ) async {
    if (images.isEmpty) return;

    final uri = Uri.parse(
      '$baseUrl/tree-module-batches/$batchId/images/',
    );

    final request = http.MultipartRequest(
      'POST',
      uri,
    );

    final token = await _getAuthToken();

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Token $token';
    }

    for (final image in images) {
      final bytes = await image.readAsBytes();

      if (bytes.isEmpty) {
        continue;
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'images',
          bytes,
          filename: image.name,
        ),
      );
    }

    if (request.files.isEmpty) {
      throw Exception('No valid image data was selected.');
    }

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(
      streamedResponse,
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Failed to upload images '
        '(${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<List<dynamic>> fetchTreeModuleBatches() async {
    final response = await http.get(
      Uri.parse('$baseUrl/tree-module-batches/'),
      headers: await _authHeaders(),
    );

    print('response for tree images includes ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load uploaded trees '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is Map && data['results'] is List) {
      return List<dynamic>.from(data['results']);
    }

    if (data is List) {
      return data;
    }

    throw Exception('Invalid tree module response.');
  }

  Future<List<Map<String, dynamic>>> fetchAvailableTreeDetails() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/tree-module-batches/available-trees/',
      ),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load available trees '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! List) {
      throw Exception('Invalid available trees response.');
    }

    return data
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

    // ============================================================
  // USERS (admin only)
  // ============================================================

  Future<List<AppUser>> fetchUsers({String? search}) async {
    final params = <String, String>{};

    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }

    String url = '$baseUrl/users/';

    if (params.isNotEmpty) {
      final query = params.entries
          .map(
            (entry) =>
                '${Uri.encodeQueryComponent(entry.key)}='
                '${Uri.encodeQueryComponent(entry.value)}',
          )
          .join('&');

      url = '$url?$query';
    }

    final List<AppUser> allUsers = [];

    while (url.isNotEmpty) {
      final response = await http.get(
        Uri.parse(url),
        headers: await _authHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load users '
          '(${response.statusCode}): ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is List) {
        allUsers.addAll(
          decoded.map(
            (e) => AppUser.fromJson(e as Map<String, dynamic>),
          ),
        );
        url = '';
        continue;
      }

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid users response.');
      }

      final results = decoded['results'] as List? ?? [];

      allUsers.addAll(
        results.map(
          (e) => AppUser.fromJson(e as Map<String, dynamic>),
        ),
      );

      final next = decoded['next'];

      url = (next == null || next.toString().trim().isEmpty)
          ? ''
          : next.toString();
    }

    return allUsers;
  }

  Future<AppUser> createUser(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode != 201) {
      throw Exception(_extractError(response, 'create user'));
    }

    return AppUser.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AppUser> updateUser(
    int id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/users/$id/'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'update user'));
    }

    return AppUser.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteUser(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$id/'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 204) {
      throw Exception(_extractError(response, 'delete user'));
    }
  }

  String _extractError(http.Response response, String action) {
    try {
      final body = jsonDecode(response.body);

      if (body is Map) {
        if (body['error'] != null) return body['error'].toString();
        if (body['detail'] != null) return body['detail'].toString();

        // DRF field-error style: {"username": ["already exists"]}
        final firstKey = body.keys.isNotEmpty ? body.keys.first : null;

        if (firstKey != null && body[firstKey] is List) {
          final messages = (body[firstKey] as List).join(', ');
          return '$firstKey: $messages';
        }
      }
    } catch (_) {}

    return 'Failed to $action (${response.statusCode}).';
  }

    // ============================================================
  // ASSIGNMENT HISTORY (real status: Assigned/Released/Removed)
  // ============================================================

  Future<List<AssignmentHistoryEntry>> fetchRecentAssignmentHistory() async {
    final response = await http.get(
      Uri.parse('$baseUrl/assignment-history/recent/'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load assignment history '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    final List results = decoded is List
        ? decoded
        : (decoded is Map ? (decoded['results'] ?? []) : []);

    return results
        .map(
          (e) => AssignmentHistoryEntry.fromJson(
            e as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<AppUser> getCurrentAppUser() async {
  final data = await fetchCurrentUser();

  return AppUser.fromJson(data);
}

Future<AppUser?> getStoredAppUser() async {
  final prefs = await SharedPreferences.getInstance();

  final userJson = prefs.getString('auth_user');

  if (userJson == null || userJson.trim().isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(userJson);

    if (decoded is Map<String, dynamic>) {
      return AppUser.fromJson(decoded);
    }

    return null;
  } catch (_) {
    return null;
  }
}
}