import 'package:flutter_test/flutter_test.dart';
import 'package:reportini/features/reports/location_service.dart';

void main() {
  test('uses the street first and deduplicates address components', () {
    expect(
      formatPlacemarkAddress(
        36.4561,
        10.7376,
        street: ' 14 Rue de la République ',
        thoroughfare: 'Autre rue',
        subLocality: ' Médina ',
        locality: 'médina',
        administrativeArea: 'Gouvernorat de Nabeul',
      ),
      '14 Rue de la République, Médina',
    );
  });

  test('skips Plus Codes and builds the street from name and number', () {
    expect(
      formatPlacemarkAddress(
        36.4561,
        10.7376,
        street: 'FP4P+M94 Nabeul',
        thoroughfare: 'Rue de la République',
        subThoroughfare: '14',
        subLocality: 'fp4p+m94',
        locality: 'Nabeul',
      ),
      '14 Rue de la République, Nabeul',
    );
  });

  test('uses the administrative area when the locality is missing', () {
    expect(
      formatPlacemarkAddress(
        36.4561,
        10.7376,
        street: 'FP4P+M94, Nabeul',
        subThoroughfare: '14',
        subLocality: 'Médina',
        locality: '  ',
        administrativeArea: 'Nabeul',
      ),
      'Médina, Nabeul',
    );
  });

  test('formats coordinates when no address component is usable', () {
    expect(
      formatPlacemarkAddress(
        35.678126,
        10.0963,
        street: '7fffFP4P+m94',
        thoroughfare: 'FP4P+M9 Nabeul',
        subLocality: ' ',
      ),
      '35.67813, 10.09630',
    );
  });
}
