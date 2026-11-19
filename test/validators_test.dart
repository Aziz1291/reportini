import 'package:flutter_test/flutter_test.dart';
import 'package:reportini/core/validators.dart';

void main() {
  test('email must have a local part and a domain', () {
    expect(validateEmail(' claire+test@reportini.tn '), isNull);
    for (final value in [
      null,
      '',
      'claire',
      'claire@',
      'claire@ville',
      'cl aire@reportini.tn',
    ]) {
      expect(validateEmail(value), isNotNull);
    }
  });

  test('password requires at least eight characters and a digit', () {
    expect(validatePassword('Ville123'), isNull);
    expect(validatePassword('Ville1'), isNotNull);
    expect(validatePassword('VilleSansChiffre'), isNotNull);
    expect(validatePassword(null), isNotNull);
  });

  test('confirmation is case-sensitive and required', () {
    expect(validateConfirmation('Ville123', 'Ville123'), isNull);
    expect(validateConfirmation('ville123', 'Ville123'), isNotNull);
    expect(validateConfirmation('', ''), isNotNull);
  });

  test('required text rejects whitespace', () {
    expect(requiredText('   ', 'Champ requis'), 'Champ requis');
    expect(requiredText(' Claire ', 'Champ requis'), isNull);
  });
}
