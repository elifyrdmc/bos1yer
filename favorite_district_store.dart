import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend/supabase_config.dart';

/// Account-owned district favorites. Device-only favorites remain available
/// only before sign-in; existing account-scoped local data is imported once.
class FavoriteDistrictStore {
  static String? get currentOwnerId => SupabaseConfig.isConfigured
      ? Supabase.instance.client.auth.currentUser?.id
      : null;

  static String keyForOwner(String? ownerId) => ownerId == null
      ? 'favorite_districts_guest'
      : 'favorite_districts_user_$ownerId';

  static Future<void> clearForOwner(String ownerId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(keyForOwner(ownerId));
  }

  static Future<List<String>> load(String? ownerId) async {
    final preferences = await SharedPreferences.getInstance();
    if (ownerId == null || !SupabaseConfig.isConfigured) {
      return preferences.getStringList(keyForOwner(ownerId)) ?? const [];
    }

    final client = Supabase.instance.client;
    _requireCurrentOwner(client, ownerId);
    final rows = await client
        .from('favorite_districts')
        .select('district_name')
        .eq('user_id', ownerId)
        .order('district_name');
    final remote = rows
        .map((row) => row['district_name'])
        .whereType<String>()
        .toSet();

    // Import legacy account-scoped preferences without discarding data before
    // the server confirms that every old favorite has been copied.
    final local = preferences.getStringList(keyForOwner(ownerId)) ?? const [];
    final toImport = local
        .where((district) => !remote.contains(district))
        .toSet();
    if (toImport.isNotEmpty) {
      await client.from('favorite_districts').insert([
        for (final district in toImport)
          {'user_id': ownerId, 'district_name': district},
      ]);
      remote.addAll(toImport);
    }
    await preferences.remove(keyForOwner(ownerId));
    return remote.toList()..sort();
  }

  static Future<void> save(String? ownerId, Iterable<String> districts) async {
    final desired = districts.toSet();
    if (ownerId == null || !SupabaseConfig.isConfigured) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
        keyForOwner(ownerId),
        desired.toList()..sort(),
      );
      return;
    }

    final client = Supabase.instance.client;
    _requireCurrentOwner(client, ownerId);
    final rows = await client
        .from('favorite_districts')
        .select('district_name')
        .eq('user_id', ownerId);
    final existing = rows
        .map((row) => row['district_name'])
        .whereType<String>()
        .toSet();
    final removed = existing.difference(desired);
    final added = desired.difference(existing);

    if (removed.isNotEmpty) {
      await client
          .from('favorite_districts')
          .delete()
          .eq('user_id', ownerId)
          .inFilter('district_name', removed.toList());
    }
    if (added.isNotEmpty) {
      await client.from('favorite_districts').insert([
        for (final district in added)
          {'user_id': ownerId, 'district_name': district},
      ]);
    }
  }

  static void _requireCurrentOwner(SupabaseClient client, String ownerId) {
    if (client.auth.currentUser?.id != ownerId) {
      throw StateError('The signed-in account changed. Reload favorites.');
    }
  }
}
