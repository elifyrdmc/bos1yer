import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_system.dart';

/// Explicit dark surfaces keep pages charcoal instead of tinting them green.
class AppearanceColors {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color fill(BuildContext context, Color light) {
    if (!isDark(context)) return light;
    if (light == ParkDesign.green ||
        light == ParkDesign.greenBright ||
        light == const Color(0xFF008545)) {
      return ParkDesign.greenBright;
    }
    if (light == ParkDesign.plum || light == const Color(0xFF73549A)) {
      return ParkDesign.darkLavender;
    }
    return ParkDesign.darkRaised;
  }

  static Color ink(BuildContext context, Color light) =>
      isDark(context) ? Theme.of(context).colorScheme.onSurface : light;
}

/// A device preference, independent of the signed-in account.
class AppAppearance {
  static final mode = ValueNotifier<ThemeMode>(ThemeMode.system);
  static final _preferences = SharedPreferencesAsync();
  static const _key = 'appearance.theme_mode';

  static Future<void> load() async {
    try {
      final saved = await _preferences.getString(_key);
      mode.value = ThemeMode.values.firstWhere(
        (value) => value.name == saved,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      // Keep the system appearance when local storage is unavailable.
    }
  }

  static Future<void> save(ThemeMode value) async {
    await _preferences.setString(_key, value.name);
    mode.value = value;
  }
}

class AppearanceSetting extends StatelessWidget {
  const AppearanceSetting({super.key});

  static String _label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Sistem',
    ThemeMode.light => 'Açık',
    ThemeMode.dark => 'Koyu',
  };

  static IconData _icon(ThemeMode mode) => switch (mode) {
    ThemeMode.system => Icons.brightness_auto_outlined,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
  };

  Future<void> _choose(BuildContext context, ThemeMode current) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Görünüm', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final option in ThemeMode.values)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  minTileHeight: 58,
                  leading: Icon(_icon(option)),
                  title: Text(_label(option)),
                  subtitle: option == ThemeMode.system
                      ? const Text('Telefonunun görünümünü kullan')
                      : null,
                  trailing: option == current
                      ? Icon(
                          Icons.check_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || selected == current) return;
    try {
      await AppAppearance.save(selected);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Görünüm kaydedilemedi. Tekrar dene.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: AppAppearance.mode,
    builder: (context, mode, _) => ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: const Text('Görünüm'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _label(mode),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: () => _choose(context, mode),
    ),
  );
}
