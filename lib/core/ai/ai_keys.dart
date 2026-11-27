// ============================================================================
//  CLÉ API DE L'ASSISTANT IA  —  À REMPLACER
// ============================================================================
//
//  Fournisseur recommandé : Google Gemini (offre gratuite, sans carte).
//  Créez une clé sur https://aistudio.google.com/apikey puis :
//
//   Option A (la plus simple)  : collez-la dans l'application,
//                                Profil > Assistant IA > Clé API > Enregistrer.
//   Option B (dans le code)    : remplacez le texte ci-dessous par votre clé.
//                                ⚠ Ne poussez jamais une vraie clé sur GitHub.
//   Option C (sans toucher au code) :
//       copiez ai.env.example.json en ai.env.json, mettez-y la clé, puis
//       flutter run --dart-define-from-file=ai.env.json
//
//  Tant que la valeur est le texte de remplacement, l'IA reste désactivée
//  et l'application fonctionne normalement sans elle.
// ============================================================================

/// Texte de remplacement : tant que la clé vaut ceci, l'IA est désactivée.
const kAiApiKeyPlaceholder = 'COLLEZ_VOTRE_CLE_API_ICI';

/// Clé API utilisée par défaut (remplaçable par --dart-define AI_API_KEY).
const kAiApiKey = String.fromEnvironment(
  'AI_API_KEY',
  defaultValue: kAiApiKeyPlaceholder,
);

/// Fournisseur par défaut : gemini, grok ou openai.
const kAiProvider = String.fromEnvironment(
  'AI_PROVIDER',
  defaultValue: 'gemini',
);

/// Modèle par défaut (vide = modèle recommandé du fournisseur).
const kAiModel = String.fromEnvironment('AI_MODEL');

/// URL de base pour un fournisseur compatible OpenAI (vide = URL officielle).
const kAiBaseUrl = String.fromEnvironment('AI_BASE_URL');
