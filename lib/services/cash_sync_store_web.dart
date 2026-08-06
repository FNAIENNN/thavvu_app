// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

class CashSyncStoreClient {
  CashSyncStoreClient({required String baseUrl})
      : _baseUrl = _normalizeBaseUrl(baseUrl);

  final String _baseUrl;

  bool get isEnabled => _baseUrl.isNotEmpty;

  Future<String?> read(String key) async {
    if (!isEnabled) return null;
    try {
      final response = await html.HttpRequest.request(
        '$_baseUrl/store/${Uri.encodeComponent(key)}',
        method: 'GET',
      );
      return response.responseText;
    } on html.ProgressEvent catch (error) {
      final request = error.target;
      if (request is html.HttpRequest && request.status == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> write(String key, String value) async {
    if (!isEnabled) return;
    await html.HttpRequest.request(
      '$_baseUrl/store/${Uri.encodeComponent(key)}',
      method: 'PUT',
      sendData: value,
      requestHeaders: const {
        'Content-Type': 'application/json; charset=utf-8',
      },
    );
  }

  Future<void> remove(String key) async {
    if (!isEnabled) return;
    await html.HttpRequest.request(
      '$_baseUrl/store/${Uri.encodeComponent(key)}',
      method: 'DELETE',
    );
  }

  static String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      // Production builds never have a local sync server. The store stays
      // disabled unless a dev explicitly opts in (dart-define at build time
      // or localStorage override). Previously this defaulted to
      // http://localhost:8787, which made deployed web apps fail every cash
      // read with ERR_CONNECTION_REFUSED.
      return html.window.localStorage['THAVVU_CASH_API_BASE'] ?? '';
    }
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
