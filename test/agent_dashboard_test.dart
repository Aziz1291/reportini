import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:reportini/core/app_state.dart';
import 'package:reportini/core/theme.dart';
import 'package:reportini/data/local/local_backend.dart';
import 'package:reportini/features/dashboard/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('agent dashboard lists and filters municipal reports', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late LocalBackend backend;
    late AppState state;
    await tester.runAsync(() async {
      await initializeDateFormatting('fr');
      backend = await LocalBackend.open(latency: Duration.zero);
      state = AppState(
        auth: backend,
        reports: backend,
        municipalities: backend,
        users: backend,
      );
      await state.signIn('agent.nabeul@reportini.tn', 'Reportini2026');
    });
    addTearDown(backend.close);
    addTearDown(state.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1100);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: civicTheme(useGoogleFonts: false),
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Agent Nabeul'), findsOneWidget);
    expect(find.text('Nabeul'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Tous (3)'), findsOneWidget);
    expect(find.text('Nid-de-poule dangereux sur chaussée'), findsOneWidget);
    expect(
      find.text('Dépôt sauvage de cartons et poubelle débordante'),
      findsOneWidget,
    );

    await tester.tap(find.text('En cours (1)'));
    await tester.pump();
    expect(find.text('Nid-de-poule dangereux sur chaussée'), findsNothing);
    expect(
      find.text('Dépôt sauvage de cartons et poubelle débordante'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('municipal-report-search')),
      'Place du Marché',
    );
    await tester.pump();
    expect(
      find.text('Dépôt sauvage de cartons et poubelle débordante'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('municipal-report-search')),
      'adresse inconnue',
    );
    await tester.pump();
    expect(find.text('Aucun signalement ne correspond.'), findsOneWidget);

    tester.view.physicalSize = const Size(390, 850);
    await tester.pump();
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
