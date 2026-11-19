# Reportini — Delivery plan (Claude = planning / Scrum Master, Codex gpt-6.2-sol = implementation)

Source of truth: `../Cahier_des_charges_Reportini.docx` (spec), `../Reportini_Etape2_ProductBacklog.pptx` (backlog),
UI mockups in `../stitch_cityreport_civic_mobile_app/stitch_cityreport_civic_mobile_app/*/code.html|screen.png`.

## Architecture decisions (ADR summary)

| # | Decision | Why |
|---|----------|-----|
| A1 | Single Flutter app (`reportini/`), Android first, web build also works. | Spec: "un seul code Flutter". |
| A2 | Role-based app: citizen gets the 8 mobile screens; agent & admin log into a **dashboard** area inside the same app (responsive, usable on phone and in Chrome). | Spec asks for a web dashboard for agent/admin; one codebase keeps it demoable on the Android emulator too. |
| A3 | **Repository layer with two backends**: `LocalBackend` (default — JSON in shared_preferences + photos in app documents dir, works offline, seeded with demo data) and `FirebaseBackend` (Auth + Firestore + Storage), selected at startup: Firebase if `lib/firebase_options.dart` is configured, otherwise Local. | No Firebase project/credentials exist yet; the APK must work out of the box. Swapping to Firebase = run `flutterfire configure`, no code change. |
| A4 | State: `provider` (ChangeNotifier). Navigation: `go_router` with a `StatefulShellRoute` bottom bar (Accueil / Mes signalements / Profil) and role-based redirects. | Simple, well-known, matches the course level. |
| A5 | Geolocation: `geolocator` (+ `geocoding` best-effort reverse geocode, fallback to "lat, lng"). Map: `flutter_map` + OpenStreetMap tiles (no API key). "Ouvrir dans le GPS" via `url_launcher` geo:/maps URL. | No paid keys. |
| A6 | Municipality routing: haversine distance from report position to each municipality centre; nearest one whose radius contains the point wins; otherwise "Hors zone" (unassigned, visible to admin). | US10. |
| A7 | Photos compressed at pick time (`image_picker` maxWidth 1280, quality 70). | NFR performance (<10 s send on 4G). |
| A8 | Statuses: `en_attente`, `en_cours`, `traite`; every change appends to a `history` timeline (shown on Détails). | Screen 7 timeline + US15. |
| A9 | UI language French, "Civic Modernist" theme: Inter (google_fonts), primary #003980. | Spec §12. |

## Data model

- `users/{uid}`: name, email, role (`citizen|agent|admin`), municipalityId (agents), createdAt
- `municipalities/{id}`: name, centerLat, centerLng, radiusKm
- `reports/{id}`: reference (`RPT-YYYY-XXXXX`), citizenId, category, title, description, photoUrl/path, lat, lng, address, accuracy, municipalityId|null, municipalityName, status, history[{status, at, by, note}], createdAt, updatedAt
- Categories: Déchets, Voirie, Éclairage, Équipement, Autre anomalie urbaine

## Seed data (LocalBackend first launch)

Municipalities: Nabeul, Hammamet, Tunis, Sousse (real centres, 5–10 km radius).
Accounts (password `Reportini2026`): `admin@reportini.tn` (admin), `agent.nabeul@reportini.tn`, `agent.hammamet@reportini.tn` (agents), `citoyen@reportini.tn` (citizen with 3 demo reports using the stitch sample photos).

## Sprints

### Sprint 1 — Release 1: Signalement et suivi citoyen (US1–US8, 23 SP)
- S1.1 US1 scaffold: project, theme, router, models, repository interfaces, LocalBackend + seed, Firebase backend skeleton, assets.
- S1.2 US2 Connexion + Inscription (validation: email, ≥8 chars + 1 digit, confirm, CGU checkbox), persistent session, logout.
- S1.3 US3–US7 Nouveau signalement (2 steps, photo camera/gallery, category chips, 250-char description, GPS + refresh + manual edit on map, send with retry snackbar on failure) → Confirmation (reference + copy).
- S1.4 US8 Accueil (welcome, CTA, last 3 reports), Mes signalements (status filters with counters), Détails (photo zoom, map, open in GPS, timeline), Profil (stats, logout).
- DoD: `flutter analyze` clean, unit tests for validators/repository, debug APK builds.

### Sprint 2 — Release 2: Traitement municipal (US9–US15, 22 SP)
- S2.1 US9 admin: CRUD municipalities (name, centre picked on map or typed, radius).
- S2.2 US10 automatic municipality assignment at send time (haversine).
- S2.3 US11 admin: create agent accounts bound to a municipality; list/disable.
- S2.4 US12–US15 agent dashboard: login, list of reports of own municipality with status filter + search, detail with map, change status (+ optional note) → visible in citizen timeline.
- Firestore + Storage security rules (`firestore.rules`, `storage.rules`) enforcing: citizen sees only own reports, agent only own municipality, admin all.
- DoD: analyze clean, tests for geo routing + permissions logic, APK builds.

### Sprint 3 — Hardening & release
- Widget tests for key flows, README (run, seed accounts, switch to Firebase), release APK, emulator smoke test (Claude verifies).
