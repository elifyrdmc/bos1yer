// Test doubles for plugins already used by the app; no new dependency.
// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

final class ProfileTestStorage extends InMemorySharedPreferencesAsync {
  ProfileTestStorage() : super.empty();
  bool failWrites = false;
  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    if (failWrites) throw StateError('Device storage unavailable');
    return super.setString(key, value, options);
  }
}

late ProfileTestStorage profileStorage;
void setupProfileStorage() {
  setUp(() {
    profileStorage = ProfileTestStorage();
    SharedPreferencesAsyncPlatform.instance = profileStorage;
  });
}
