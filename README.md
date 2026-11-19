# Reportini

Reportini permet aux citoyens de signaler des problèmes dans l’espace public et aux municipalités de suivre les interventions. La même application Flutter s’utilise sur Android et dans un navigateur, avec une interface en français.

## Fonctionnalités

| Livraison | Fonctionnalités |
| --- | --- |
| Sprint 1 · US1 à US8 | Inscription et connexion, dépôt d’un constat avec photo et géolocalisation, référence de confirmation, suivi des signalements et profil citoyen. |
| Sprint 2 · US9 à US15 | Tableau de bord municipal adaptatif, gestion des zones et des comptes agents, affectation automatique ou manuelle, indicateurs, recherche, filtres et historique des interventions. |

Le tableau de bord agent affiche les signalements de sa municipalité. L’administration dispose des totaux par municipalité et par statut, ainsi que d’une vue **Hors zone** pour affecter les constats non couverts. Lors du dépôt, Reportini sélectionne le centre le plus proche parmi les zones dont le rayon contient les coordonnées.

## Sprint 3

- Adresses lisibles à partir des données de géocodage. Les Plus Codes sont écartés et les coordonnées s’affichent à cinq décimales si besoin.
- Les municipalités sont classées par ordre alphabétique dans la vue administrative, avec **Hors zone** en dernier. La mise à jour du mode local ajoute quatre constats de démonstration une seule fois en conservant les données existantes.
- Les cartes de signalement annoncent le titre, le statut et l’adresse aux lecteurs d’écran. Les listes vides affichent un message adapté et la connexion propose une aide en cas d’oubli du mot de passe.
- La sélection manuelle sur la carte reste disponible si la permission GPS est bloquée. Sur Android, le formulaire permet aussi d’ouvrir les réglages de l’application. Le bouton d’envoi est désactivé pendant la transmission.
- Les icônes Android et Web utilisent le logo de Reportini.

## Architecture

- `lib/core/` contient la navigation par rôle, l’état Provider, le thème Civic Modernist et le calcul de distance.
- `lib/features/` contient les écrans citoyens et le tableau de bord dans `dashboard/`.
- `lib/data/` contient les modèles, les interfaces des dépôts et les deux implémentations. **LocalBackend** conserve les données sur l’appareil avec SharedPreferences. **FirebaseBackend** utilise Authentication, Firestore et Storage.
- `firestore.rules` et `storage.rules` définissent les accès Firebase. Les déploiements utilisent `firebase.json`.

Le mode local est destiné à la démonstration sur un appareil. Les fonds de carte OpenStreetMap nécessitent une connexion. En mode Firebase, les listes et les historiques sont synchronisés entre les appareils. La suppression retire une municipalité des zones actives et conserve son document en archive pour préserver les références en cas d’affectation concurrente. L’application bloque a priori la suppression d’une municipalité liée à un agent ou à un signalement.

## Lancer la démonstration

Depuis la racine du projet, avec Flutter et Dart compatibles avec `pubspec.yaml`.

```sh
flutter pub get
flutter run
flutter run -d chrome
```

## Captures / démonstration

En mode local, Nabeul, Hammamet, Tunis et Sousse sont disponibles. Le compte citoyen contient sept constats de démonstration, dont un à Kairouan dans **Hors zone**.

| Rôle | E-mail |
| --- | --- |
| Administration | `admin@reportini.tn` |
| Agent de Nabeul | `agent.nabeul@reportini.tn` |
| Agent de Hammamet | `agent.hammamet@reportini.tn` |
| Citoyen | `citoyen@reportini.tn` |

Mot de passe commun aux comptes locaux de démonstration **`Reportini2026`**.

1. Connectez-vous avec le compte citoyen. Depuis **Accueil**, créez un signalement avec une photo et choisissez un lieu à Nabeul. Envoyez le constat et relevez sa référence sur l’écran de confirmation.
2. Déconnectez-vous, puis ouvrez le compte agent de Nabeul sur la même installation. Retrouvez le constat par sa référence, passez-le à **En cours**, puis à **Traité**, avec une note d’intervention.
3. Reconnectez-vous avec le compte citoyen. Dans **Mes signalements**, ouvrez le constat pour voir le statut **Traité** et l’historique de l’intervention.

## Activer Firebase

1. Créez un projet Firebase. Activez la connexion par e-mail et mot de passe, créez la base Firestore par défaut et provisionnez le bucket Storage. Installez la CLI Firebase et connectez-vous au compte qui administre le projet.
2. Générez les options FlutterFire pour Android et le Web.

   ```sh
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

3. Ajoutez ou rétablissez `static const isConfigured = true;` dans la classe générée `DefaultFirebaseOptions` de `lib/firebase_options.dart`. Conservez les options générées pour les plateformes sélectionnées.
4. Déployez les règles. Lors du premier déploiement, accordez à Storage l’autorisation de consulter Firestore si la CLI le demande.

   ```sh
   firebase deploy --only firestore:rules,storage --project VOTRE_ID_PROJET
   ```

5. Dans Firebase Authentication, créez le premier utilisateur administrateur. Dans Firestore, créez le document `users/{uid}` avec son UID exact. Renseignez `name` et `email` comme chaînes, `role` avec la chaîne `admin`, `municipalityId` à null, `enabled` à true et `createdAt` avec un Timestamp. Connectez-vous dans Reportini avec les identifiants de ce compte.
6. Depuis le tableau de bord, créez les municipalités, puis les comptes agents. Les comptes et constats de démonstration sont propres au mode local. L’activation d’un compte agent est gérée dans son profil Firestore et contrôlée à chaque attribution de droits.

Pour le Web, configurez le CORS du bucket Storage pour les origines utilisées par l’application afin de permettre le chargement des photos via le SDK. Le SDK FlutterFire Web utilise des liens de téléchargement à jeton pour lire les photos. L’application conserve les références Storage dans les nouveaux constats. Un lien à jeton déjà obtenu reste utilisable jusqu’à la révocation du jeton. Les anciens signalements Firebase peuvent nécessiter un renseignement administratif du champ `citizenName` pour afficher le nom dans le tableau de bord.

## Tests et builds

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter build web
```

Les tests couvrent les validations, le routage géographique, les autorisations, les comptes agents, l’historique, l’affectation manuelle et l’affichage filtré du tableau de bord. Ils couvrent aussi le formatage des adresses, la migration des données de démonstration et la connexion du citoyen jusqu’à l’accueil. Les tests Flutter utilisent le mode local et des préférences simulées.
