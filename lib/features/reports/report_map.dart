import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/models/report.dart';

const defaultMapCenter = LatLng(36.4561, 10.7376);

class ReportMap extends StatelessWidget {
  const ReportMap({
    super.key,
    required this.center,
    required this.point,
    this.onSelect,
    this.controller,
    this.zoom,
    this.radiusKm,
  });
  final LatLng center;
  final LatLng? point;
  final ValueChanged<LatLng>? onSelect;
  final MapController? controller;
  final double? zoom;
  final double? radiusKm;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom ?? (point == null ? 13 : 16),
        maxZoom: 19,
        interactionOptions: InteractionOptions(
          flags: onSelect == null
              ? InteractiveFlag.none
              : InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: onSelect == null ? null : (_, position) => onSelect!(position),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: applicationId,
          maxNativeZoom: 19,
        ),
        if (radiusKm case final radius? when point != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: point!,
                radius: radius.clamp(0.0, 20015.0).toDouble() * 1000,
                useRadiusInMeter: true,
                color: civicBlue.withValues(alpha: .16),
                borderColor: civicBlue,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        if (point case final selected?)
          MarkerLayer(
            markers: [
              Marker(
                point: selected,
                width: 42,
                height: 42,
                alignment: Alignment.topCenter,
                child: const Icon(
                  Icons.location_on,
                  color: civicBlue,
                  size: 42,
                  shadows: [Shadow(color: Colors.white, blurRadius: 10)],
                ),
              ),
            ],
          ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap',
              onTap: () =>
                  launchUrl(Uri.https('www.openstreetmap.org', '/copyright')),
            ),
          ],
        ),
      ],
    ),
  );
}

class MapSelectionScreen extends StatefulWidget {
  const MapSelectionScreen({super.key, this.current});
  final ReportLocation? current;

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  LatLng? _point;

  @override
  void initState() {
    super.initState();
    if (widget.current case final current?) {
      _point = LatLng(current.lat, current.lng);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.current;
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier la localisation')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Touchez la carte pour placer le repère sur le lieu du constat.',
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ReportMap(
                      center: initial == null
                          ? defaultMapCenter
                          : LatLng(initial.lat, initial.lng),
                      point: _point,
                      onSelect: (position) => setState(() => _point = position),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_point case final point?)
                    Text(
                      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                      textAlign: TextAlign.center,
                    ),
                  TextButton(
                    onPressed: () async {
                      final point = await showDialog<LatLng>(
                        context: context,
                        builder: (context) =>
                            _CoordinatesDialog(initial: _point),
                      );
                      if (point != null && context.mounted) {
                        Navigator.of(context).pop(point);
                      }
                    },
                    child: const Text('Saisir les coordonnées'),
                  ),
                  FilledButton.icon(
                    onPressed: _point == null
                        ? null
                        : () => Navigator.of(context).pop(_point),
                    icon: const Icon(Icons.check),
                    label: const Text('Confirmer cet emplacement'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoordinatesDialog extends StatefulWidget {
  const _CoordinatesDialog({this.initial});
  final LatLng? initial;

  @override
  State<_CoordinatesDialog> createState() => _CoordinatesDialogState();
}

class _CoordinatesDialogState extends State<_CoordinatesDialog> {
  late final _lat = TextEditingController(
    text: widget.initial?.latitude.toString(),
  );
  late final _lng = TextEditingController(
    text: widget.initial?.longitude.toString(),
  );
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  double? _number(String? input) =>
      double.tryParse(input?.trim().replaceAll(',', '.') ?? '');

  String? _validate(String? input, int limit) {
    final value = _number(input);
    return value == null || !value.isFinite || value.abs() > limit
        ? 'Valeur entre −$limit et $limit.'
        : null;
  }

  Widget _field(String label, TextEditingController controller, int limit) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        validator: (value) => _validate(value, limit),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Coordonnées du constat'),
    scrollable: true,
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _field('Latitude', _lat, 90),
          const SizedBox(height: 12),
          _field('Longitude', _lng, 180),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.of(context)
                .pop(LatLng(_number(_lat.text)!, _number(_lng.text)!));
          }
        },
        child: const Text('Confirmer'),
      ),
    ],
  );
}

Future<void> openInGps(BuildContext context, ReportLocation location) async {
  final coordinates = '${location.lat},${location.lng}';
  try {
    if (!kIsWeb && Theme.of(context).platform == TargetPlatform.android) {
      try {
        if (await launchUrl(
          Uri.parse('geo:$coordinates?q=$coordinates'),
          mode: LaunchMode.externalApplication,
        )) {
          return;
        }
      } catch (_) {
        // Continue with the browser-compatible URL.
      }
    }
    if (await launchUrl(
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': coordinates,
      }),
      mode: LaunchMode.externalApplication,
    )) {
      return;
    }
  } catch (_) {
    // Show actionable feedback when neither URL can be opened.
  }
  if (context.mounted) {
    showMessage(context, 'Impossible d’ouvrir cette position dans le GPS.');
  }
}
