import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkist/main.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Mount the map UI directly when a test is about map behavior.
/// Map widget tests focus on HomeScreen and do not require live Supabase auth.
Future<void> pumpHomeScreen(WidgetTester tester) async {
  // HomeScreen also mounts RewardsPage, which reads device storage on startup.
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
}
