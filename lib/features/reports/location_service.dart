import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/report.dart';
import '../../data/repositories/auth_repository.dart';

Future<ReportLocation> locateDevice() async {
  if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
    throw const RepositoryException(
      'Le GPS est désactivé. Activez-le ou choisissez un point sur la carte.',
    );
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw const RepositoryException(
      'L’accès à votre position est refusé. Autorisez-le dans les réglages ou utilisez la carte.',
    );
  }
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 12),
    ),
  );
  return resolveLocation(
    position.latitude,
    position.longitude,
    accuracy: position.accuracy,
  );
}

Future<ReportLocation> resolveLocation(
  double lat,
  double lng, {
  double? accuracy,
}) async {
  var address = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  if (!kIsWeb) {
    try {
      final places = await placemarkFromCoordinates(
        lat,
        lng,
      ).timeout(const Duration(seconds: 4));
      if (places.isNotEmpty) {
        final place = places.first;
        final parts = [place.street, place.postalCode, place.locality]
            .whereType<String>()
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toSet();
        if (parts.isNotEmpty) address = parts.join(', ');
      }
    } catch (_) {
      // Coordinates remain usable when the geocoding service is unavailable.
    }
  }
  return ReportLocation(lat, lng, address, accuracy: accuracy);
}
