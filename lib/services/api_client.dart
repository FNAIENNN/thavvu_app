import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// HTTP bridge used on Flutter web (and as a fallback) to talk to the
/// Vercel `/api` Postgres proxy. Native builds prefer direct `postgres`.
class ApiClient {
  ApiClient({String? baseUrl})
      : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'THAVVU_API_BASE',
              defaultValue: '',
            );

  /// Empty baseUrl means same-origin (`/api/...`) which is correct on Vercel.
  final String baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final root = baseUrl.isEmpty ? '' : baseUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$root/api$normalized').replace(queryParameters: query);
  }

  Future<bool> ping() async {
    try {
      final res = await http.get(_uri('/ping')).timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final res = await http
        .post(
          _uri('/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Map<String, dynamic>.from(body['user'] as Map);
  }

  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, String>? query,
  }) async {
    final res = await http.get(_uri(path, query)).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw StateError('API $path failed: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is! List) return [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final res = await http
        .post(
          _uri(path),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('API $path failed: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    return body;
  }

  static bool get preferHttp => kIsWeb;
}
