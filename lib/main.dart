import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/ai/ai_service.dart';
import 'core/app_state.dart';
import 'core/theme.dart';
import 'data/firebase/firebase_backend.dart';
import 'data/local/local_backend.dart';
import 'firebase_options.dart';

late AiService _ai;

Future<AppState> _initialize() async {
  await initializeDateFormatting('fr');
  _ai = await AiService.load();
  final AppState state;
  if (DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final backend = FirebaseBackend(
      FirebaseAuth.instance,
      FirebaseFirestore.instance,
      FirebaseStorage.instance,
    );
    state = AppState(
      auth: backend,
      reports: backend,
      municipalities: backend,
      users: backend,
    );
  } else {
    final backend = await LocalBackend.open();
    state = AppState(
      auth: backend,
      reports: backend,
      municipalities: backend,
      users: backend,
    );
  }
  try {
    await state.restore();
  } catch (_) {
    state.dispose();
    rethrow;
  }
  return state;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<AppState> _startup = _initialize();

  @override
  Widget build(BuildContext context) => FutureBuilder<AppState>(
    future: _startup,
    builder: (context, snapshot) {
      if (snapshot.data case final state?) {
        return ReportiniApp(state: state, ai: _ai);
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: civicTheme(useGoogleFonts: false),
        home: Scaffold(
          body: Center(
            child: snapshot.hasError
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Impossible de démarrer Reportini.'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () =>
                              setState(() => _startup = _initialize()),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(
                    semanticsLabel: 'Ouverture de Reportini',
                  ),
          ),
        ),
      );
    },
  );
}
