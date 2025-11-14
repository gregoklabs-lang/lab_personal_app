import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseCredentials {
  /// URL de tu proyecto de Supabase.
  ///
  /// Lee primero la variable del archivo `.env` o de los `--dart-define`
  /// utilizados en tiempo de compilación.
  static String get supabaseUrl =>
      dotenv.maybeGet('SUPABASE_URL') ??
      const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: _defaultSupabaseUrl,
      );

  /// Clave pública (anon key) de tu proyecto Supabase.
  ///
  /// Lee primero la variable del archivo `.env` o de los `--dart-define`
  /// utilizados en tiempo de compilación.
  static String get supabaseAnonKey =>
      dotenv.maybeGet('SUPABASE_ANON_KEY') ??
      const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: _defaultSupabaseAnonKey,
      );

  static String get devicesTable =>
      _readConfig('SUPABASE_TABLE_DEVICES', 'cultivemos_devices');

  static String get userSettingsTable =>
      _readConfig('SUPABASE_TABLE_USER_SETTINGS', 'cultivemos_user_settings');

  static String get setpointsTable =>
      _readConfig('SUPABASE_TABLE_SETPOINTS', 'cultivemos_setpoints');

  static String _readConfig(String key, String fallback) {
    return dotenv.maybeGet(key) ??
        String.fromEnvironment(key, defaultValue: fallback);
  }

  static const String _defaultSupabaseUrl = 'https://your-project.supabase.co';
  static const String _defaultSupabaseAnonKey = 'public-anon-key';
}
