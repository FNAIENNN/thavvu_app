/// Central Supabase configuration.
///
/// Reads from `--dart-define` at build time so secrets never have to live
/// in source control. Falls back to the current dev project values so the
/// app keeps working without extra build flags (dev only — override via
/// dart-define in production builds).
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qpecrrhindaegcdfcbuz.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_gaW1B6hiRyf82hX5SL7HJQ_GnU-ZVjU',
  );
}
