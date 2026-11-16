import 'package:supabase_flutter/supabase_flutter.dart';

/// Build-time Supabase settings for the live client integration.
///
/// When no project settings are supplied, the app uses its limited demo path.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured =>
      url.startsWith('https://') &&
      url.endsWith('.supabase.co') &&
      publishableKey.startsWith('sb_publishable_') &&
      !publishableKey.endsWith('replace-me');

  static Future<void> initializeIfConfigured() async {
    if (!isConfigured) return;

    await Supabase.initialize(url: url, publishableKey: publishableKey);
  }
}
