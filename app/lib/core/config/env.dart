/// Compile-time environment configuration.
///
/// Values are injected at build/run time via `--dart-define` so that no
/// credentials are hardcoded in source. The Supabase URL and anon
/// (publishable) key are public-by-design; RLS is what protects data.
///
/// Example:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Whether the required configuration is present. Used to fail fast with a
  /// helpful message instead of an opaque network error.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
