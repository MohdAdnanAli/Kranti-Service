import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int status;
  final Map<String, dynamic>? errors;
  ApiException(this.message, this.status, [this.errors]);
  @override
  String toString() => message;
}

/// Talks to the demo server. The server's clock is used for countdowns.
class Api {
  static int offsetMs = 0;
  static int serverNow() => DateTime.now().millisecondsSinceEpoch + offsetMs;

  String base;
  String? token;
  Api(this.base);

  Uri _uri(String path) =>
      Uri.parse(base.replaceAll(RegExp(r'/+$'), '') + path);

  Future<http.Response> _request(
    String method,
    String path,
    Object? body,
  ) async {
    try {
      final req = http.Request(method, _uri(path));
      req.headers['Content-Type'] = 'application/json';
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      if (body != null) req.body = jsonEncode(body);
      final streamed = await req.send().timeout(const Duration(seconds: 15));
      return await http.Response.fromStream(streamed);
    } catch (e) {
      throw ApiException(
        'Cannot reach the server at $base. Is it running? ($e)',
        0,
      );
    }
  }

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final r = await _request(method, path, body);
    dynamic data;
    try {
      data = r.body.isEmpty ? null : jsonDecode(r.body);
    } catch (_) {
      data = null;
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return data;
    String msg = 'Request failed (${r.statusCode}).';
    Map<String, dynamic>? errors;
    if (data is Map) {
      if (data['error'] is String) msg = data['error'] as String;
      if (data['errors'] is Map)
        errors = Map<String, dynamic>.from(data['errors'] as Map);
    }
    throw ApiException(msg, r.statusCode, errors);
  }

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body ?? <String, dynamic>{});
  Future<dynamic> put(String path, Object body) => _send('PUT', path, body);
  Future<dynamic> patch(String path, Object body) => _send('PATCH', path, body);
  Future<dynamic> delete(String path) => _send('DELETE', path);
}
