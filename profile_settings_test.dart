import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkist/profile_settings_page.dart';

import 'profile_test_storage.dart';

Future<void> openProfile(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const Scaffold(appBar: null, body: ProfileSettingsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapLabel(
  WidgetTester tester,
  String label, {
  double delta = 220,
}) async {
  final finder = label == 'Ayarlar' ? find.byTooltip(label) : find.text(label);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> savePhotoPreview(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Değişiklikleri kaydet');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setupProfileStorage();
  testWidgets(
    'Profile validates and saves separate names in local fallback mode',
    (tester) async {
      await openProfile(tester);
      expect(find.text('Sürücü'), findsOneWidget);
      await tapLabel(tester, 'Profili düzenle');
      await tester.enterText(find.byType(TextFormField).first, '');
      await tapLabel(tester, 'Değişiklikleri kaydet');
      expect(find.text('Ad alanı boş bırakılamaz.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '  Elif  ');
      await tester.enterText(find.byType(TextFormField).last, '  Naz  ');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Değişiklikleri kaydet');
      expect(find.text('Elif Naz'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Photo picker errors leave the preview editor usable', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/image_picker');
    var pickerCalls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      _,
    ) async {
      pickerCalls++;
      throw PlatformException(code: 'denied');
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await openProfile(tester);
    await tapLabel(tester, 'Profili düzenle');
    await tapLabel(tester, 'Profil fotoğrafı seç');
    expect(pickerCalls, 1);
    expect(
      find.text('Fotoğraf seçilemedi. Fotoğrafsız devam edebilirsin.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Değişiklikleri kaydet'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Selected profile photo can be previewed, cancelled and removed locally',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/image_picker');
      final photo = File('test/fixtures/report_photo.png').absolute;
      String? reply = photo.path;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => reply,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await openProfile(tester);
      await tester.runAsync(
        () => precacheImage(
          FileImage(photo),
          tester.element(find.byType(MaterialApp)),
        ),
      );
      await tapLabel(tester, 'Profili düzenle');
      await tapLabel(tester, 'Profil fotoğrafı seç');
      expect(find.byType(Image), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Deneme');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      reply = null;
      await tapLabel(tester, 'Profil fotoğrafı seç');
      expect(find.byType(Image), findsOneWidget);
      await tapLabel(tester, 'Profil fotoğrafını kaldır');
      expect(find.byType(Image), findsNothing);
      await tapLabel(tester, 'Değişiklikleri kaydet');
      expect(find.byType(Image), findsNothing);
      expect(find.text('Deneme'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Notification controls stay demo-only and retain district and quiet hours',
    (tester) async {
      await openProfile(tester);
      await tapLabel(tester, 'Ayarlar');
      await tapLabel(tester, 'İlçe, çevre ve sessiz saatler');
      final master = find.byKey(const ValueKey('notifications-enabled'));
      final district = find.byKey(const ValueKey('district-alerts'));
      expect(tester.widget<SwitchListTile>(district).onChanged, isNull);
      await tester.tap(master);
      await tester.pumpAndSettle();
      await tester.tap(district);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Bildirim ilçesi'),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Kadıköy'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Kadıköy').last);
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Sessiz saatler');
      await tapLabel(tester, 'Başlangıç: 22:00');
      expect(find.byType(TimePickerDialog), findsOneWidget);
      final fields = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '23');
      await tester.enterText(fields.at(1), '30');
      await tester.tap(find.text('Seç'));
      await tester.pumpAndSettle();
      expect(find.text('Başlangıç: 23:30'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapLabel(tester, 'İlçe, çevre ve sessiz saatler');
      expect(find.text('Kadıköy'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(master).value, isTrue);
      await tester.scrollUntilVisible(
        find.text('Başlangıç: 23:30'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Başlangıç: 23:30'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Settings omit unavailable account actions and explain foreground use',
    (tester) async {
      await openProfile(tester);
      await tapLabel(tester, 'Ayarlar');
      expect(find.text('Verilerimi indir'), findsNothing);
      expect(find.text('Hesabımı sil'), findsNothing);
      expect(find.text('Tüm cihazlardan çıkış'), findsNothing);
      await tapLabel(tester, 'Konum ve görünürlük', delta: -200);
      expect(find.text('Konum yalnızca kullanım sırasında'), findsOneWidget);
      expect(
        find.textContaining('Arka planda konum takibi yapılmaz.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Profile and settings fit a narrow phone with larger text', (
    tester,
  ) async {
    await openProfile(tester, width: 320, scale: 1.4);
    expect(tester.takeException(), isNull);
    await tapLabel(tester, 'Ayarlar');
    await tester.scrollUntilVisible(
      find.text('Uygulama ve park bilgisi'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tapLabel(tester, 'Uygulama ve park bilgisi');
    expect(find.text('BOŞ1YER · Park paylaşım uygulaması'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
