import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Thin HTTP client around the CivicAI FastAPI backend.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
      : baseUrl = baseUrl ?? _defaultBaseUrl(),
        _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  String? _token;

  static String _defaultBaseUrl() {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (kIsWeb) return 'http://127.0.0.1:8000/api/v1';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }

  void setToken(String? token) => _token = token;

  Map<String, String> _headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    final params = <String, String>{};
    query.forEach((key, value) {
      if (value != null) params[key] = value.toString();
    });
    return uri.replace(queryParameters: {...uri.queryParameters, ...params});
  }

  Future<dynamic> _send(
    Future<http.Response> Function() request,
  ) async {
    late http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 20));
    } catch (error) {
      throw ApiException(
        'Cannot reach the CivicAI service. Check that the backend is running '
        'and that the API URL is reachable from this device.',
      );
    }

    final body = response.body.isEmpty ? null : _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (response.statusCode == 401) {
      throw ApiException('Your session has expired. Sign in again.',
          statusCode: 401);
    }

    throw ApiException(_errorMessage(body, response.statusCode),
        statusCode: response.statusCode);
  }

  dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  String _errorMessage(dynamic body, int status) {
    if (body is Map && body['detail'] != null) {
      final detail = body['detail'];
      if (detail is String) return detail;
      if (detail is List) {
        final messages = detail
            .whereType<Map>()
            .map((entry) => entry['msg']?.toString())
            .whereType<String>()
            .toList();
        if (messages.isNotEmpty) return messages.join(', ');
      }
    }
    if (status == 403) return 'You do not have access to this action.';
    if (status == 404) return 'The requested record could not be found.';
    return 'Request failed with status $status.';
  }

  Map<String, dynamic> _map(dynamic body) =>
      body is Map<String, dynamic> ? body : <String, dynamic>{};

  // ---------------------------------------------------------------- auth
  Future<({String token, String refreshToken, User user})> login(
    String email,
    String password,
  ) async {
    final body = _map(await _send(() => _http.post(
          _uri('/auth/login'),
          headers: _headers(),
          body: jsonEncode({'email': email.trim(), 'password': password}),
        )));
    return (
      token: body['access_token'] as String? ?? '',
      refreshToken: body['refresh_token'] as String? ?? '',
      user: User.fromJson(_map(body['user'])),
    );
  }

  Future<({String token, String refreshToken, User user})> register({
    required String fullName,
    required String email,
    required String password,
    String? phoneNumber,
    String? ward,
  }) async {
    final body = _map(await _send(() => _http.post(
          _uri('/auth/register'),
          headers: _headers(),
          body: jsonEncode({
            'full_name': fullName.trim(),
            'email': email.trim(),
            'password': password,
            if (phoneNumber != null && phoneNumber.isNotEmpty)
              'phone_number': phoneNumber,
            if (ward != null && ward.isNotEmpty) 'ward': ward,
          }),
        )));
    return (
      token: body['access_token'] as String? ?? '',
      refreshToken: body['refresh_token'] as String? ?? '',
      user: User.fromJson(_map(body['user'])),
    );
  }

  Future<User> me() async =>
      User.fromJson(_map(await _send(() => _http.get(
            _uri('/auth/me'),
            headers: _headers(),
          ))));

  Future<User> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? ward,
  }) async =>
      User.fromJson(_map(await _send(() => _http.put(
            _uri('/auth/me'),
            headers: _headers(),
            body: jsonEncode({
              'full_name': ?fullName,
              'phone_number': ?phoneNumber,
              'ward': ?ward,
            }),
          ))));

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _send(() => _http.post(
          _uri('/auth/change-password'),
          headers: _headers(),
          body: jsonEncode({
            'current_password': currentPassword,
            'new_password': newPassword,
          }),
        ));
  }

  // ----------------------------------------------------------- lookups
  Future<Lookups> lookups() async {
    final responses = await Future.wait([
      _send(() => _http.get(_uri('/departments'), headers: _headers())),
      _send(() => _http.get(_uri('/categories'), headers: _headers())),
    ]);
    final departments = (responses[0] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Department.fromJson)
        .toList();
    final categories = (responses[1] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ComplaintCategory.fromJson)
        .toList();
    return Lookups(departments: departments, categories: categories);
  }

  // -------------------------------------------------------- complaints
  Future<ComplaintPage> complaints({
    String? status,
    String? search,
    String? priority,
    String? ward,
    bool overdue = false,
    bool assignedToMe = false,
    int skip = 0,
    int limit = 20,
  }) async =>
      ComplaintPage.fromJson(_map(await _send(() => _http.get(
            _uri('/complaints/paged', {
              'status': status,
              'search': search,
              'priority': priority,
              'ward': ward,
              'overdue': overdue ? 'true' : null,
              'assigned_to_me': assignedToMe ? 'true' : null,
              'skip': skip,
              'limit': limit,
            }),
            headers: _headers(),
          ))));

  Future<ComplaintDetail> complaint(int id) async =>
      ComplaintDetail.fromJson(_map(await _send(() => _http.get(
            _uri('/complaints/$id'),
            headers: _headers(),
          ))));

  Future<ComplaintDetail> createComplaint({
    required int departmentId,
    required int categoryId,
    required String title,
    required String description,
    required String ward,
    required String address,
    String? landmark,
    double? latitude,
    double? longitude,
  }) async =>
      ComplaintDetail.fromJson(_map(await _send(() => _http.post(
            _uri('/complaints'),
            headers: _headers(),
            body: jsonEncode({
              'department_id': departmentId,
              'category_id': categoryId,
              'title': title,
              'description': description,
              'ward': ward,
              'address': address,
              if (landmark != null && landmark.isNotEmpty)
                'landmark': landmark,
              'latitude': ?latitude,
              'longitude': ?longitude,
            }),
          ))));

  Future<ComplaintDetail> updateStatus(
    int id, {
    required String status,
    String? comments,
  }) async =>
      ComplaintDetail.fromJson(_map(await _send(() => _http.put(
            _uri('/complaints/$id/status'),
            headers: _headers(),
            body: jsonEncode({
              'status': status,
              if (comments != null && comments.isNotEmpty)
                'comments': comments,
            }),
          ))));

  Future<Attachment> uploadAttachment(
    int complaintId, {
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/complaints/$complaintId/attachments'),
    );
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName,
    ));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = response.body.isEmpty ? null : _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Attachment.fromJson(_map(body));
    }
    throw ApiException(
      _errorMessage(body, response.statusCode),
      statusCode: response.statusCode,
    );
  }

  // --------------------------------------------------------- analytics
  Future<AnalyticsOverview> analytics({int days = 30}) async =>
      AnalyticsOverview.fromJson(_map(await _send(() => _http.get(
            _uri('/analytics/overview', {'days': days}),
            headers: _headers(),
          ))));

  Future<HotspotFeed> hotspots({int daysBack = 90}) async =>
      HotspotFeed.fromJson(_map(await _send(() => _http.get(
            _uri('/ai/hotspots', {'days_back': daysBack}),
            headers: _headers(),
          ))));

  // ----------------------------------------------------- notifications
  Future<NotificationFeed> notifications({int limit = 50}) async =>
      NotificationFeed.fromJson(_map(await _send(() => _http.get(
            _uri('/notifications', {'limit': limit}),
            headers: _headers(),
          ))));

  Future<void> markNotificationRead(int id) async {
    await _send(() => _http.put(
          _uri('/notifications/$id/read'),
          headers: _headers(),
        ));
  }

  Future<void> markAllNotificationsRead() async {
    await _send(() => _http.post(
          _uri('/notifications/read-all'),
          headers: _headers(),
        ));
  }

  Future<void> deleteNotification(int id) async {
    await _send(() => _http.delete(
          _uri('/notifications/$id'),
          headers: _headers(),
        ));
  }

  Future<int> unreadNotifications() async {
    final body = _map(await _send(() => _http.get(
          _uri('/notifications/unread-count'),
          headers: _headers(),
        )));
    return (body['unread_count'] as num?)?.toInt() ?? 0;
  }

  String fileUrl(String path) {
    final origin = Uri.parse(baseUrl).origin;
    if (path.startsWith('http')) return path;
    return '$origin${path.startsWith('/') ? '' : '/'}$path';
  }
}
