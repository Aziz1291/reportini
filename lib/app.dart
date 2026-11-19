import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/router.dart';
import 'core/theme.dart';

class ReportiniApp extends StatefulWidget {
  const ReportiniApp({super.key, required this.state});
  final AppState state;

  @override
  State<ReportiniApp> createState() => _ReportiniAppState();
}

class _ReportiniAppState extends State<ReportiniApp> {
  late final GoRouter _router = createRouter(widget.state);
  late final ThemeData _theme = civicTheme();

  @override
  void dispose() {
    _router.dispose();
    widget.state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: widget.state,
    child: MaterialApp.router(
      title: 'Reportini',
      debugShowCheckedModeBanner: false,
      theme: _theme,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: _router,
    ),
  );
}
