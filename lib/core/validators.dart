String? requiredText(String? value, String message) =>
    value?.trim().isNotEmpty == true ? null : message;

String? validateEmail(String? value) {
  if (value == null ||
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
    return 'Saisissez une adresse e-mail valide.';
  }
  return null;
}

bool hasPasswordDigit(String value) => RegExp(r'\d').hasMatch(value);

String? validatePassword(String? value) {
  if (value == null || value.length < 8 || !hasPasswordDigit(value)) {
    return 'Utilisez au moins 8 caractères et un chiffre.';
  }
  return null;
}

String? validateConfirmation(String? value, String password) =>
    value == password && password.isNotEmpty
    ? null
    : 'Les mots de passe ne correspondent pas.';

String? validateCoordinate(double? value, int limit) =>
    value == null || !value.isFinite || value.abs() > limit
    ? 'Saisissez une valeur entre −$limit et $limit.'
    : null;

String? validateRadius(double? value) =>
    value == null || !value.isFinite || value <= 0
    ? 'Saisissez un rayon strictement positif.'
    : null;
