import 'package:flutter/material.dart';

/// Shared visual language for the map, report forms and account screens.
/// Parking status colors remain separate from the brand accent.
abstract final class ParkDesign {
  static const green = Color(0xFF087C53);
  static const greenBright = Color(0xFFB4CE2E);
  // Button accents are intentionally separate from the wider green palette so
  // map/status colors and soft surface tints do not change with button tuning.
  static const buttonGreen = Color(0xFF017634);
  static const buttonGreenDark = Color(0xFF679B7C);
  static const buttonActionDark = Color(0xFF91C9A6);
  static const destructiveButtonDark = Color(0xFFA85B52);
  static const destructiveActionDark = Color(0xFFC47A5E);
  static const greenSoft = Color(0xFFE8F5ED);
  static const ink = Color(0xFF202723);
  static const muted = Color(0xFF5B665F);
  static const paper = Color(0xFFF8F9F5);
  static const white = Color(0xFFFFFFFF);
  static const line = Color(0xFFDDE3DA);
  static const groupOutline = Color(0xFFB6D4C1);
  static const darkGroupOutline = Color(0xFF3B5143);
  static const lavender = Color(0xFFEDE8F3);
  static const wordmarkLavender = Color(0xFF82649F);
  static const plum = Color(0xFF4A2650);

  static const darkPage = Color(0xFF101210);
  static const darkSurface = Color(0xFF1C201D);
  static const darkCardSurface = Color(0xFF222322);
  static const darkRaised = Color(0xFF292E29);
  static const darkLine = Color(0xFF394039);
  static const darkInk = Color(0xFFF0F2EC);
  static const darkMuted = Color(0xFFB8C1B7);
  static const darkLavender = Color(0xFF302B36);

  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space24 = 24.0;
  static const space32 = 32.0;
  static const radius = 16.0;

  static Color primaryButton(Brightness brightness) =>
      brightness == Brightness.dark ? buttonGreenDark : buttonGreen;

  static Color primaryButtonForeground(Brightness brightness) =>
      brightness == Brightness.dark ? darkPage : white;

  static Color buttonAction(Brightness brightness) =>
      brightness == Brightness.dark ? buttonActionDark : buttonGreen;

  static Color destructiveButton(Brightness brightness) =>
      brightness == Brightness.dark
      ? destructiveButtonDark
      : const Color(0xFFB44438);

  static Color destructiveAction(Brightness brightness) =>
      brightness == Brightness.dark
      ? destructiveActionDark
      : const Color(0xFFB44438);

  static ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: dark ? buttonGreenDark : green,
      onPrimary: dark ? darkPage : white,
      primaryContainer: dark ? darkRaised : greenSoft,
      onPrimaryContainer: dark ? buttonActionDark : green,
      secondary: dark ? darkMuted : muted,
      onSecondary: darkPage,
      secondaryContainer: dark ? darkRaised : const Color(0xFFEFF2EA),
      onSecondaryContainer: dark ? darkInk : ink,
      tertiary: dark ? const Color(0xFFD3BEDD) : plum,
      onTertiary: dark ? darkPage : white,
      tertiaryContainer: dark ? darkLavender : lavender,
      onTertiaryContainer: dark ? darkInk : plum,
      error: dark ? const Color(0xFFFFA59A) : const Color(0xFFB44438),
      onError: darkPage,
      surface: dark ? darkSurface : white,
      onSurface: dark ? darkInk : ink,
      onSurfaceVariant: dark ? darkMuted : muted,
      outline: dark ? darkLine : line,
      outlineVariant: dark ? darkLine : line,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: dark ? white : darkSurface,
      onInverseSurface: dark ? ink : white,
      inversePrimary: dark ? green : greenBright,
      surfaceTint: Colors.transparent,
    );
    const radius16 = BorderRadius.all(Radius.circular(radius));
    final page = dark ? darkPage : paper;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: page,
      canvasColor: page,
      dividerColor: scheme.outline,
      iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontSize: 29,
          height: 1.14,
          fontWeight: FontWeight.w800,
          letterSpacing: -.65,
          color: scheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -.35,
          color: scheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.45,
          color: scheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: scheme.onSurface,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: page,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -.35,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius16,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: radius16,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius16,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius16,
          borderSide: BorderSide(color: scheme.primary, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius16,
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryButton(brightness),
          foregroundColor: primaryButtonForeground(brightness),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius16),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryButton(brightness),
          foregroundColor: primaryButtonForeground(brightness),
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonAction(brightness),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: radius16),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: buttonAction(brightness)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.primaryContainer,
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: radius16),
      ),
    );
  }
}

/// Theme-aware BOŞ1YER lockup using the supplied icon and wordmark artwork.
/// The wordmark files preserve the approved lettering and contrast by theme.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    required this.iconSize,
    this.wordmarkHeight,
    this.gap = 8,
  });

  final double iconSize;
  final double? wordmarkHeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final markHeight = wordmarkHeight ?? iconSize * .5;
    return Semantics(
      label: 'BOŞ1YER',
      image: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/brand/bos1yer_icon.png',
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
          SizedBox(width: gap),
          Image.asset(
            isDark
                ? 'assets/brand/bos1yer_wordmark_dark.png'
                : 'assets/brand/bos1yer_wordmark_light.png',
            height: markHeight,
            width: markHeight * 3,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ],
      ),
    );
  }
}

/// Compact, reusable account/settings section without a nested card.
class ParkListSection extends StatelessWidget {
  const ParkListSection({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Material(
            color: colors.brightness == Brightness.dark
                ? ParkDesign.darkSurface
                : ParkDesign.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ParkDesign.radius),
              side: BorderSide(
                color: colors.brightness == Brightness.dark
                    ? ParkDesign.darkGroupOutline
                    : ParkDesign.groupOutline,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 56, color: colors.outline),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A short help item keeps guidance scannable without hiding key rules.
class ParkHelpStep extends StatelessWidget {
  const ParkHelpStep({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: ParkDesign.space24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: colors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
