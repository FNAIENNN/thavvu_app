import 'cash_sync_store_stub.dart'
    if (dart.library.html) 'cash_sync_store_web.dart'
    if (dart.library.io) 'cash_sync_store_io.dart';

class CashSyncStore {
  CashSyncStore({String? baseUrl})
      : _client = CashSyncStoreClient(
          baseUrl: baseUrl ?? _configuredBaseUrl,
        );

  static const String _configuredBaseUrl =
      String.fromEnvironment('THAVVU_CASH_API_BASE');

  final CashSyncStoreClient _client;

  bool get isEnabled => _client.isEnabled;

  Future<String?> read(String key) => _client.read(key);

  Future<void> write(String key, String value) => _client.write(key, value);

  Future<void> remove(String key) => _client.remove(key);
}
