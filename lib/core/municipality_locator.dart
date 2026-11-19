import 'dart:math' as math;

import '../data/models/municipality.dart';

class MunicipalityLocator {
  const MunicipalityLocator();

  Municipality? locate(
    double lat,
    double lng,
    Iterable<Municipality> municipalities,
  ) {
    Municipality? nearest;
    var distanceToNearest = double.infinity;
    for (final municipality in municipalities) {
      final distance = distanceKm(
        lat,
        lng,
        municipality.centerLat,
        municipality.centerLng,
      );
      if (distance <= municipality.radiusKm && distance < distanceToNearest) {
        nearest = municipality;
        distanceToNearest = distance;
      }
    }
    return nearest;
  }

  double distanceKm(double lat, double lng, double otherLat, double otherLng) {
    const radians = math.pi / 180;
    final latitude = math.sin((otherLat - lat) * radians / 2);
    final longitude = math.sin((otherLng - lng) * radians / 2);
    final a =
        latitude * latitude +
        math.cos(lat * radians) *
            math.cos(otherLat * radians) *
            longitude *
            longitude;
    return 6371 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }
}
