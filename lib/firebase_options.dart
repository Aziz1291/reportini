import 'package:firebase_core/firebase_core.dart';

/// Supply the FlutterFire options for Android and web, then enable Firebase.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static const isConfigured = false;

  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Configurez les options Firebase avant de les activer.',
  );
}
