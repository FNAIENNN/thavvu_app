/// Database connection settings for Thavvu Supabase Postgres.
///
/// Prefer compile-time overrides:
///   flutter run --dart-define=THAVVU_DB_HOST=... --dart-define=THAVVU_DB_PASSWORD=...
///
/// Defaults target the project's Supabase transaction pooler (IPv4-friendly).
class DbConfig {
  DbConfig._();

  static const String host = String.fromEnvironment(
    'THAVVU_DB_HOST',
    defaultValue: 'aws-1-ap-northeast-2.pooler.supabase.com',
  );
  static const int port = int.fromEnvironment(
    'THAVVU_DB_PORT',
    defaultValue: 6543,
  );
  static const String database = String.fromEnvironment(
    'THAVVU_DB_NAME',
    defaultValue: 'postgres',
  );
  static const String username = String.fromEnvironment(
    'THAVVU_DB_USER',
    defaultValue: 'postgres.qpecrrhindaegcdfcbuz',
  );
  static const String password = String.fromEnvironment(
    'THAVVU_DB_PASSWORD',
    defaultValue: 'waswEg-tuxqir-nogga8',
  );
  static const bool useSsl = bool.fromEnvironment(
    'THAVVU_DB_SSL',
    defaultValue: true,
  );

  static bool get isConfigured => password.isNotEmpty && host.isNotEmpty;
}
