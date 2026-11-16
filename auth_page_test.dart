import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkist/auth_page.dart';

Future<void> openAuth(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
}) async {
  await tester.binding.setSurfaceSize(Size(width, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MaterialApp(home: AuthPage()));
  await tester.pumpAndSettle();
}

Future<void> openSignUp(WidgetTester tester) async {
  final email = find.text('E-posta ile devam et');
  await tester.ensureVisible(email);
  await tester.tap(email);
  await tester.pumpAndSettle();
  final signUp = find.text('Hesap oluştur');
  await tester.ensureVisible(signUp);
  await tester.tap(signUp);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed-out entry offers separate sign-up and sign-in paths', (
    tester,
  ) async {
    await openAuth(tester);
    expect(find.text('Boş park yerini bul, paylaş.'), findsOneWidget);
    expect(find.text('E-posta ile devam et'), findsOneWidget);
    expect(find.text('Google ile devam et'), findsOneWidget);
    expect(find.text('Apple ile devam et'), findsOneWidget);
    expect(find.text('Yakında'), findsNWidgets(2));

    await tester.tap(find.text('E-posta ile devam et'));
    await tester.pumpAndSettle();
    expect(find.text('Tekrar hoş geldin'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Google ile devam et'), findsOneWidget);
    expect(find.text('Apple ile devam et'), findsOneWidget);
    await tester.tap(find.text('Şifremi unuttum'));
    await tester.pumpAndSettle();
    expect(find.text('Şifreni yenile'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Bağlantı gönder'));
    await tester.pumpAndSettle();
    expect(
      find.text('Şifre sıfırlama bağlantısı için e-postanı yaz.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Giriş ekranına dön'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Karşılama ekranına dön'));
    await tester.pumpAndSettle();
    expect(find.text('Boş park yerini bul, paylaş.'), findsOneWidget);
  });

  testWidgets('sign-up opens readable legal drafts and retains form state', (
    tester,
  ) async {
    await openAuth(tester);
    await openSignUp(tester);
    expect(find.text('Aramıza katıl'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(5));

    await tester.enterText(find.byType(TextFormField).first, 'Esra');
    await tester.tap(
      find.textContaining('Kullanım koşulları', findRichText: true),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Taslak metin — yayın öncesi hukuk incelemesi gerekir.'),
      findsOneWidget,
    );
    expect(find.text('Bu sayfa hukuki belge değildir'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField).first, findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Esra',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'sign-up requires both draft acknowledgements without recording consent',
    (tester) async {
      await openAuth(tester);
      await openSignUp(tester);
      final createButton = find.widgetWithText(FilledButton, 'Hesap oluştur');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('iki taslak bilgilendirmeyi'), findsOneWidget);

      for (final entry in [
        (0, 'Esra'),
        (1, 'Yıldız'),
        (2, 'esra@example.com'),
        (3, 'Password1'),
        (4, 'Password1'),
      ]) {
        final field = find.byType(TextFormField).at(entry.$1);
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.$2);
      }
      for (var index = 0; index < 2; index++) {
        final checkbox = find.byType(Checkbox).at(index);
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
      }
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Hesap servisi henüz yapılandırılmadı'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('compact sign-up remains scrollable and has no layout overflow', (
    tester,
  ) async {
    await openAuth(tester, width: 320, height: 568);
    expect(tester.takeException(), isNull, reason: 'Welcome at 320px');
    await openSignUp(tester);
    expect(tester.takeException(), isNull, reason: 'Sign-up at 320px');
    final submit = find.widgetWithText(FilledButton, 'Hesap oluştur');
    await tester.ensureVisible(submit);
    expect(submit, findsOneWidget);
    final firstNameField = find.byType(TextFormField).first;
    await tester.ensureVisible(firstNameField);
    await tester.tap(firstNameField);
    await tester.pumpAndSettle();
    await tester.enterText(firstNameField, 'Ada');
    await tester.ensureVisible(submit);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
