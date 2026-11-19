import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/report.dart';
import '../../data/repositories/auth_repository.dart';

class LocationPermissionPermanentlyDenied extends RepositoryException {
  const LocationPermissionPermanentlyDenied()
    : super(
        'L’accès à votre position est bloqué. Autorisez-le dans les réglages ou choisissez un point sur la carte.',
      );
}

Future<ReportLocation> locateDevice() async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw const LocationPermissionPermanentlyDenied();
  }
  if (permission == LocationPermission.denied) {
    throw const RepositoryException(
      'L’accès à votre position est refusé. Réessayez ou choisissez un point sur la carte.',
    );
  }
  if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
    throw const RepositoryException(
      'Le GPS est désactivé. Activez-le ou choisissez un point sur la carte.',
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

final _plusCode = RegExp(
  r'^[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,3}(?:$|[\s,])',
  caseSensitive: false,
);
final _addressWhitespace = RegExp(r'\s+');

String? _addressComponent(String? value) {
  final text = value?.trim().replaceAll(_addressWhitespace, ' ');
  return text == null || text.isEmpty || _plusCode.hasMatch(text) ? null : text;
}

String formatPlacemarkAddress(
  double lat,
  double lng, {
  String? street,
  String? thoroughfare,
  String? subThoroughfare,
  String? subLocality,
  String? locality,
  String? administrativeArea,
}) {
  var road = _addressComponent(street);
  if (road == null) {
    final name = _addressComponent(thoroughfare);
    final number = _addressComponent(subThoroughfare);
    if (name != null) {
      road = number == null || number.toLowerCase() == name.toLowerCase()
          ? name
          : '$number $name';
    }
  }
  final components = [
    road,
    _addressComponent(subLocality),
    _addressComponent(locality) ?? _addressComponent(administrativeArea),
  ];
  final seen = <String>{};
  final parts = components
      .whereType<String>()
      .expand((part) => part.split(','))
      .map(_addressComponent)
      .whereType<String>()
      .where((part) => seen.add(part.toLowerCase()))
      .toList();
  return parts.isEmpty
      ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
      : parts.join(', ');
}

Future<ReportLocation> resolveLocation(
  double lat,
  double lng, {
  double? accuracy,
}) async {
  var address = formatPlacemarkAddress(lat, lng);
  if (!kIsWeb) {
    try {
      final places = await placemarkFromCoordinates(
        lat,
        lng,
      ).timeout(const Duration(seconds: 4));
      if (places.isNotEmpty) {
        final place = places.first;
        address = formatPlacemarkAddress(
          lat,
          lng,
          street: place.street,
          thoroughfare: place.thoroughfare,
          subThoroughfare: place.subThoroughfare,
          subLocality: place.subLocality,
          locality: place.locality,
          administrativeArea: place.administrativeArea,
        );
      }
    } catch (_) {
      // Coordinates remain usable when the geocoding service is unavailable.
    }
  }
  return ReportLocation(lat, lng, address, accuracy: accuracy);
}
