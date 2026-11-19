import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:reportini/core/app_state.dart';
import 'package:reportini/core/router.dart';
import 'package:reportini/core/theme.dart';
import 'package:reportini/data/local/local_backend.dart';
import 'package:reportini/features/auth/auth_screen.dart';
import 'package:reportini/features/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets('seed citizen signs in and sees the Accueil greeting', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('fr');
    final backend = await LocalBackend.open(latency: Duration.zero);
    final state = AppState(
      auth: backend,
      reports: backend,
      municipalities: backend,
      users: backend,
    );
    final router = createRouter(state);
    addTearDown(backend.close);
    addTearDown(state.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp.router(
          theme: civicTheme(useGoogleFonts: false),
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'citoyen@reportini.tn',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'Reportini2026',
    );
    final submit = find.byKey(const Key('auth-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Accueil'), findsWidgets);
    expect(find.textContaining('Bonjour Claire'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
