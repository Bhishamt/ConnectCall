class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://eqrpzlgtgbsmlndhpmgw.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_LEQmgOprs2UXST4E8SF40A_GKkksuFJ',
  );

  static String get anonKey =>
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: publishableKey);
}
