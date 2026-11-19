# Reportini

Application Flutter de signalement et de suivi des problèmes urbains. Le Sprint 1 contient les huit écrans citoyens et une page d’accueil provisoire pour les comptes municipaux.

## Démarrage

Avec Flutter 3.47.5, le SDK Android 36 et le JDK 17 pour Android, exécutez les commandes suivantes à la racine du projet.

```sh
flutter pub get
flutter run
flutter run -d chrome
```

Le premier démarrage initialise le backend local. Les comptes, les sessions et les signalements restent sur cet appareil ou dans ce navigateur. La carte OpenStreetMap utilise une connexion Internet. Sur le web, la géolocalisation nécessite HTTPS ou localhost et l’adresse se présente sous forme de coordonnées.

### Comptes de démonstration

Mot de passe commun **Reportini2026**.

| Adresse | Rôle |
|---|---|
| citoyen@reportini.tn | Citoyen, avec trois signalements de démonstration |
| agent.nabeul@reportini.tn | Agent de Nabeul |
| agent.hammamet@reportini.tn | Agent de Hammamet |
| admin@reportini.tn | Administrateur |

### Firebase

Le backend distant utilise Firebase Authentication (e-mail et mot de passe), Cloud Firestore et Firebase Storage. Générer les options FlutterFire pour Android et web dans `lib/firebase_options.dart` et conserver le membre statique `DefaultFirebaseOptions.isConfigured` avec la valeur `true`. Configurer les services et leurs règles d’accès avant de l’utiliser. Les comptes et les quatre municipalités du mode local ne sont pas importés automatiquement dans Firebase. Le schéma des collections figure dans [le plan](docs/PLAN.md).

## Vérification

```sh
flutter analyze
flutter test
flutter build apk --debug
```

