import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/ai/ai_service.dart';
import 'core/app_state.dart';
import 'core/router.dart';
import 'core/theme.dart';

class ReportiniApp extends StatefulWidget {
  const ReportiniApp({super.key, required this.state, this.ai});
  final AppState state;

  /// AI photo recognition settings; defaults to the build-time key.
  final AiService? ai;

  @override
  State<ReportiniApp> createState() => _ReportiniAppState();
}

class _ReportiniAppState extends State<ReportiniApp> {
  late final GoRouter _router = createRouter(widget.state);
  late final ThemeData _theme = civicTheme();
  late final AiService _ai = widget.ai ?? AiService();

  @override
  void dispose() {
    _router.dispose();
    widget.state.dispose();
    _ai.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: widget.state),
      ChangeNotifierProvider.value(value: _ai),
    ],
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
