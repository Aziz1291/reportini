import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/ui.dart';
import '../../core/validators.dart';
import '../../data/models/municipality.dart';
import '../../data/repositories/municipality_repository.dart';
import '../reports/report_map.dart';
import 'dashboard_widgets.dart';

class MunicipalityManagement extends StatelessWidget {
  const MunicipalityManagement({super.key, required this.municipalities});
  final List<Municipality> municipalities;

  void _edit(
    BuildContext context,
    MunicipalityRepository repository, [
    Municipality? item,
  ]) {
    showDialog<void>(
      context: context,
      builder: (context) =>
          _MunicipalityEditor(repository: repository, item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<AppState>().municipalities;
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: municipalities.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardHeading(
                'Municipalités',
                action: FilledButton.icon(
                  onPressed: () => _edit(context, repository),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une municipalité'),
                ),
              ),
              const SizedBox(height: 16),
              if (municipalities.isEmpty)
                const Text('Aucune municipalité enregistrée.'),
            ],
          );
        }
        final item = municipalities[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: CivicCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.apartment_outlined),
              title: Text(item.name),
              subtitle: Text(
                '${item.centerLat.toStringAsFixed(5)}, ${item.centerLng.toStringAsFixed(5)}'
                ' · ${item.radiusKm} km',
              ),
              onTap: () => _edit(context, repository, item),
              trailing: PopupMenuButton<bool>(
                tooltip: 'Actions pour ${item.name}',
                onSelected: (remove) {
                  if (remove) {
                    showDialog<void>(
                      context: context,
                      builder: (context) => DashboardFormDialog(
                        title: 'Supprimer ${item.name} ?',
                        submitLabel: 'Supprimer',
                        onSubmit: () => repository.deleteMunicipality(item.id),
                        child: const Text(
                          'La zone sera retirée de l’affectation des nouveaux signalements.',
                        ),
                      ),
                    );
                  } else {
                    _edit(context, repository, item);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: false, child: Text('Modifier')),
                  PopupMenuItem(value: true, child: Text('Supprimer')),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MunicipalityEditor extends StatefulWidget {
  const _MunicipalityEditor({required this.repository, this.item});
  final MunicipalityRepository repository;
  final Municipality? item;

  @override
  State<_MunicipalityEditor> createState() => _MunicipalityEditorState();
}

class _MunicipalityEditorState extends State<_MunicipalityEditor> {
  late final _name = TextEditingController(text: widget.item?.name);
  late final _lat = TextEditingController(
    text: widget.item?.centerLat.toString(),
  );
  late final _lng = TextEditingController(
    text: widget.item?.centerLng.toString(),
  );
  late final _radius = TextEditingController(
    text: widget.item?.radiusKm.toString(),
  );
  final _map = MapController();
  late final _initialCenter = _point ?? defaultMapCenter;
  late final _initialZoom = _zoom(_number(_radius.text));

  double? _number(String? text) =>
      double.tryParse(text?.trim().replaceAll(',', '.') ?? '');

  LatLng? get _point {
    final lat = _number(_lat.text);
    final lng = _number(_lng.text);
    if (validateCoordinate(lat, 90) != null ||
        validateCoordinate(lng, 180) != null) {
      return null;
    }
    return LatLng(lat!, lng!);
  }

  double _zoom(double? radius) => validateRadius(radius) == null
      ? (11 - math.log(radius! / 10) / math.ln2).clamp(2.0, 18.0).toDouble()
      : 11;

  void _pick(LatLng position) => setState(() {
    _lat.text = position.latitude.toStringAsFixed(6);
    _lng.text = position.longitude.toStringAsFixed(6);
  });

  Future<void> _save() async {
    final point = _point!;
    await widget.repository.saveMunicipality(
      Municipality(
        widget.item?.id ?? '',
        _name.text,
        point.latitude,
        point.longitude,
        _number(_radius.text)!,
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _lat.dispose();
    _lng.dispose();
    _radius.dispose();
    _map.dispose();
    super.dispose();
  }

  Widget _numericField(
    String label,
    TextEditingController controller,
    String? Function(double?) validator, {
    bool signed = true,
  }) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(
      decimal: true,
      signed: signed,
    ),
    decoration: InputDecoration(labelText: label),
    validator: (value) => validator(_number(value)),
    onChanged: (_) => setState(() {}),
  );

  @override
  Widget build(BuildContext context) {
    final point = _point;
    final radius = _number(_radius.text);
    return DashboardFormDialog(
      title: widget.item == null
          ? 'Ajouter une municipalité'
          : 'Modifier la municipalité',
      submitLabel: 'Enregistrer',
      onSubmit: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom'),
            validator: (value) =>
                requiredText(value, 'Saisissez le nom de la municipalité.'),
          ),
          const SizedBox(height: 12),
          _numericField(
            'Latitude',
            _lat,
            (value) => validateCoordinate(value, 90),
          ),
          const SizedBox(height: 12),
          _numericField(
            'Longitude',
            _lng,
            (value) => validateCoordinate(value, 180),
          ),
          const SizedBox(height: 12),
          _numericField('Rayon (km)', _radius, validateRadius, signed: false),
          const SizedBox(height: 12),
          const Text('Touchez la carte pour choisir le centre de la zone.'),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: ReportMap(
              controller: _map,
              center: _initialCenter,
              zoom: _initialZoom,
              point: point,
              radiusKm: validateRadius(radius) == null ? radius : null,
              onSelect: _pick,
            ),
          ),
          TextButton.icon(
            onPressed: point == null
                ? null
                : () => _map.move(point, _zoom(radius)),
            icon: const Icon(Icons.my_location),
            label: const Text('Recentrer sur les coordonnées'),
          ),
        ],
      ),
    );
  }
}
