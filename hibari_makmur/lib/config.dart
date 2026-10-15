/// Konfigurasi Supabase diisi saat menjalankan aplikasi, contoh:
///
///   flutter run -d chrome \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_KEY=sb_publishable_... (atau anon key lama)
///
/// Kalau tidak diisi, aplikasi berjalan dalam mode demo (tanpa internet).
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  static bool get pakaiSupabase => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
