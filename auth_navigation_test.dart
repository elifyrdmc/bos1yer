import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkist/auth_page.dart';

void main() {
  testWidgets('sign-out navigation clears the protected profile route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const Text('Giriş ve kayıt'),
                TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: Builder(
                          builder: (profileContext) => TextButton(
                            onPressed: () => closeProfileAfterSignOut(
                              Navigator.of(profileContext, rootNavigator: true),
                            ),
                            child: const Text('Çıkış yap'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Profili aç'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Profili aç'));
    await tester.pumpAndSettle();
    expect(find.text('Çıkış yap'), findsOneWidget);

    await tester.tap(find.text('Çıkış yap'));
    await tester.pumpAndSettle();

    expect(find.text('Giriş ve kayıt'), findsOneWidget);
    expect(find.text('Çıkış yap'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Giriş ve kayıt'), findsOneWidget);
  });
}
