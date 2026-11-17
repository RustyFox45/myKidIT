/// Global configuration for MyKidIT.
///
/// Supports both offline/mock-first development and live Supabase + Gemini
/// Edge Function integration via `--dart-define`.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String aiVerifyEdgeFunctionName = String.fromEnvironment(
    'AI_VERIFY_FUNCTION',
    defaultValue: 'verify-chore-photo',
  );

  /// Returns `true` only when both `SUPABASE_URL` and `SUPABASE_ANON_KEY`
  /// are provided via `--dart-define`.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

