import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportini/core/theme.dart';
import 'package:reportini/features/auth/auth_screen.dart';

void main() {
  testWidgets('login renders and validates email and password', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: civicTheme(useGoogleFonts: false),
        home: const AuthScreen(),
      ),
    );

    expect(find.text('REPORTINI'), findsOneWidget);
    expect(find.text('Espace citoyen et municipal'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'adresse-invalide',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'courte');
    final submit = find.byKey(const Key('auth-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Saisissez une adresse e-mail valide.'), findsOneWidget);
    expect(
      find.text('Utilisez au moins 8 caractères et un chiffre.'),
      findsOneWidget,
    );
  });
}
