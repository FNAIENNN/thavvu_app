class CashSyncStoreClient {
  CashSyncStoreClient({required String baseUrl});

  bool get isEnabled => false;

  Future<String?> read(String key) async => null;

  Future<void> write(String key, String value) async {}

  Future<void> remove(String key) async {}
}
