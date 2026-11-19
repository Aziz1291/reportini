import 'package:flutter_test/flutter_test.dart';
import 'package:reportini/core/municipality_locator.dart';
import 'package:reportini/data/models/municipality.dart';

void main() {
  const locator = MunicipalityLocator();
  const nabeul = Municipality('nabeul', 'Nabeul', 36.4561, 10.7376, 7);
  const hammamet = Municipality('hammamet', 'Hammamet', 36.4000, 10.6167, 8);

  test('haversine distance is in kilometers', () {
    expect(locator.distanceKm(0, 0, 0, 1), closeTo(111.195, 0.001));
    expect(locator.distanceKm(0, 179, 0, -179), closeTo(222.390, 0.001));
  });

  test('selects the nearest municipality in overlapping coverage', () {
    expect(locator.locate(36.425, 10.688, [hammamet, nabeul]), same(nabeul));
  });

  test('skips a nearer centre when outside its radius', () {
    const narrow = Municipality('narrow', 'Narrow', 36.4561, 10.7376, 0.01);
    const wide = Municipality('wide', 'Wide', 36.48, 10.74, 8);
    expect(locator.locate(36.457, 10.7376, [narrow, wide]), same(wide));
  });

  test(
    'includes the boundary and leaves points outside every zone unassigned',
    () {
      final radius = locator.distanceKm(0, 0, 0, 1);
      final boundary = Municipality('boundary', 'Boundary', 0, 0, radius);
      expect(locator.locate(0, 1, [boundary]), same(boundary));
      expect(locator.locate(36.8065, 10.1815, [nabeul, hammamet]), isNull);
      expect(locator.locate(0, 0, []), isNull);
    },
  );
}
