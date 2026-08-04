import 'dart:convert';
import 'dart:io';

class CashSyncStoreClient {
  CashSyncStoreClient({required String baseUrl})
      : _baseUrl = _normalizeBaseUrl(baseUrl);

  final String _baseUrl;

  bool get isEnabled => _baseUrl.isNotEmpty;

  Future<String?> read(String key) async {
    if (!isEnabled) return null;
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('$_baseUrl/store/${Uri.encodeComponent(key)}'),
      );
      final response = await request.close();
      if (response.statusCode == HttpStatus.notFound) return null;
      _throwIfFailed(response.statusCode);
      return utf8.decode(await response.expand((chunk) => chunk).toList());
    } finally {
      client.close(force: true);
    }
  }

  Future<void> write(String key, String value) async {
    if (!isEnabled) return;
    final client = HttpClient();
    try {
      final request = await client.putUrl(
        Uri.parse('$_baseUrl/store/${Uri.encodeComponent(key)}'),
      );
      request.headers.contentType =
          ContentType('application', 'json', charset: 'utf-8');
      request.write(value);
      final response = await request.close();
      _throwIfFailed(response.statusCode);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> remove(String key) async {
    if (!isEnabled) return;
    final client = HttpClient();
    try {
      final request = await client.deleteUrl(
        Uri.parse('$_baseUrl/store/${Uri.encodeComponent(key)}'),
      );
      final response = await request.close();
      _throwIfFailed(response.statusCode);
    } finally {
      client.close(force: true);
    }
  }

  static void _throwIfFailed(int statusCode) {
    if (statusCode < 200 || statusCode >= 300) {
      throw HttpException('Cash sync request failed with status $statusCode');
    }
  }

  static String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
