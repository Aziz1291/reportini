import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/validators.dart';
import '../../data/models/report.dart';
import '../../data/repositories/auth_repository.dart';
import 'location_service.dart';
import 'report_map.dart';
import 'report_widgets.dart';

class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key});

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  final _id = const Uuid().v4();
  final _picker = ImagePicker();
  final _details = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _scroll = ScrollController();
  XFile? _photo;
  Uint8List? _preview;
  ReportCategory? _category;
  ReportLocation? _location;
  String? _locationError;
  bool _permissionPermanentlyDenied = false;
  bool _choosingPhoto = false;
  bool _locating = false;
  bool _sending = false;
  bool _showDetails = false;
  bool _requestedLocation = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_recoverPhoto());
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _recoverPhoto() async {
    try {
      final lost = await _picker.retrieveLostData();
      final files = lost.files;
      if (files != null &&
          files.isNotEmpty &&
          _photo == null &&
          !_choosingPhoto) {
        final bytes = await files.first.readAsBytes();
        if (mounted && _photo == null && !_choosingPhoto && bytes.isNotEmpty) {
          setState(() {
            _photo = files.first;
            _preview = bytes;
          });
        }
      } else if (lost.exception != null && mounted) {
        showMessage(context, 'La photo n’a pas pu être récupérée.');
      }
    } catch (_) {
      if (mounted) showMessage(context, 'La photo n’a pas pu être récupérée.');
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_choosingPhoto) return;
    setState(() => _choosingPhoto = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw const FormatException('Photo vide');
      if (!mounted) return;
      setState(() {
        _photo = file;
        _preview = bytes;
      });
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Impossible d’ajouter la photo. Vérifiez les autorisations ou essayez la galerie.',
        );
      }
    } finally {
      if (mounted) setState(() => _choosingPhoto = false);
    }
  }

  void _next() {
    if (_photo == null || _category == null) {
      showMessage(context, 'Ajoutez une photo et sélectionnez une catégorie.');
      return;
    }
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _showDetails = true);
    if (!_requestedLocation) {
      _requestedLocation = true;
      unawaited(_refreshLocation());
    }
  }

  void _back() {
    if (_sending) return;
    if (_showDetails) {
      FocusScope.of(context).unfocus();
      if (_scroll.hasClients) _scroll.jumpTo(0);
      setState(() => _showDetails = false);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/accueil');
    }
  }

  Future<void> _refreshLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
      _permissionPermanentlyDenied = false;
    });
    try {
      final location = await locateDevice();
      if (mounted) setState(() => _location = location);
    } on RepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _locationError = error.message;
          _permissionPermanentlyDenied =
              error is LocationPermissionPermanentlyDenied;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationError = 'Position GPS indisponible. Réessayez ou choisissez un point sur la carte.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openLocationSettings() async {
    try {
      if (await Geolocator.openAppSettings()) return;
    } catch (_) {
      // The manual location picker remains available.
    }
    if (mounted) {
      showMessage(
        context,
        'Impossible d’ouvrir les réglages. Ouvrez-les depuis votre appareil ou utilisez la carte.',
      );
    }
  }

  Future<void> _editLocation() async {
    if (_locating) return;
    final point = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (context) => MapSelectionScreen(current: _location),
      ),
    );
    if (point == null || !mounted) return;
    setState(() {
      _locating = true;
      _locationError = null;
      _permissionPermanentlyDenied = false;
    });
    final location = await resolveLocation(point.latitude, point.longitude);
    if (mounted) {
      setState(() {
        _location = location;
        _locating = false;
      });
    }
  }

  Future<void> _send() async {
    if (!mounted ||
        _sending ||
        !_showDetails ||
        _locating ||
        !_details.currentState!.validate()) {
      return;
    }
    final location = _location;
    if (location == null) {
      showMessage(context, 'Indiquez le lieu du constat avant l’envoi.');
      return;
    }
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    setState(() => _sending = true);
    try {
      final report = await context.read<AppState>().submit(
        ReportDraft(
          id: _id,
          category: _category!,
          title: _title.text.trim(),
          description: _description.text.trim(),
          location: location,
          photo: _photo!,
          municipality: null,
        ),
      );
      if (mounted) context.go('/confirmation/${report.id}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      final detail = error is RepositoryException ? ' ${error.message}' : '';
      messenger.showSnackBar(
        SnackBar(
          content: Text('Échec de l’envoi.$detail'),
          action: SnackBarAction(label: 'Réessayer', onPressed: _send),
        ),
      );
    }
  }

  Widget _photoStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CivicCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ReportSection(
              Icons.add_a_photo_outlined,
              'Photo du constat',
              trailing: Text(
                'Obligatoire',
                style: TextStyle(color: civicMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                child: _preview == null
                    ? const ColoredBox(
                        color: civicTint,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 36,
                              color: civicBlue,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Ajouter une photo',
                              style: TextStyle(color: civicBlue),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(
                            _preview!,
                            fit: BoxFit.cover,
                            semanticLabel: 'Photo du constat',
                          ),
                          const Positioned(
                            top: 10,
                            left: 10,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                child: Text(
                                  'Photo sélectionnée',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _choosingPhoto
                      ? null
                      : () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(_photo == null ? 'Caméra' : 'Reprendre'),
                ),
                OutlinedButton.icon(
                  onPressed: _choosingPhoto
                      ? null
                      : () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Galerie'),
                ),
              ],
            ),
            if (_choosingPhoto) const LinearProgressIndicator(),
          ],
        ),
      ),
      const SizedBox(height: 16),
      CivicCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ReportSection(
              Icons.category_outlined,
              'Catégorie de l’incident',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in ReportCategory.values)
                  ChoiceChip(
                    avatar: Icon(
                      categoryIcon(category),
                      size: 17,
                      color: _category == category ? Colors.white : civicBlue,
                    ),
                    selectedColor: civicBlue,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: _category == category ? Colors.white : civicInk,
                    ),
                    label: Text(category.label),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _detailsStep(BuildContext context) {
    final location = _location;
    return Form(
      key: _details,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CivicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ReportSection(Icons.edit_note, 'Précisions'),
                const SizedBox(height: 6),
                const Text(
                  'Aidez les agents techniques à intervenir plus rapidement.',
                  style: TextStyle(color: civicMuted),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  enabled: !_sending,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    hintText: 'Ex. Nid-de-poule sur la chaussée',
                    counterText: '',
                  ),
                  validator: (value) =>
                      requiredText(value, 'Donnez un titre au signalement.'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _description,
                  enabled: !_sending,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 250,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description (facultatif)',
                    alignLabelWithHint: true,
                    hintText: 'Précisez l’emplacement exact, la dangerosité…',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CivicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ReportSection(
                  Icons.pin_drop_outlined,
                  'Localisation précise',
                ),
                const SizedBox(height: 10),
                if (_locating) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 10),
                  const Text('Recherche de la position…'),
                ],
                if (_locationError case final error?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        style: const TextStyle(color: civicMuted),
                      ),
                    ),
                  ),
                if (location != null) ...[
                  SizedBox(
                    height: 132,
                    child: ReportMap(
                      key: ValueKey((location.lat, location.lng)),
                      center: LatLng(location.lat, location.lng),
                      point: LatLng(location.lat, location.lng),
                    ),
                  ),
                  const SizedBox(height: 10),
                  MetadataLine(Icons.location_on_outlined, location.address),
                  const SizedBox(height: 4),
                  Text(
                    location.accuracy == null
                        ? 'Emplacement choisi sur la carte'
                        : 'GPS actif · Précision ±${location.accuracy!.round()} m',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: civicMuted),
                  ),
                ] else if (!_locating && _locationError == null)
                  const Text('Choisissez le lieu du constat.'),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _locating || _sending ? null : _editLocation,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(
                    location == null ? 'Choisir sur la carte' : 'Modifier',
                  ),
                ),
                const SizedBox(height: 6),
                if (_permissionPermanentlyDenied && !kIsWeb) ...[
                  OutlinedButton.icon(
                    onPressed: _sending ? null : _openLocationSettings,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Ouvrir les réglages de l’application'),
                  ),
                  const SizedBox(height: 6),
                ],
                OutlinedButton.icon(
                  onPressed: _locating || _sending ? null : _refreshLocation,
                  icon: const Icon(Icons.gps_fixed, size: 18),
                  label: const Text('Rafraîchir ma position'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending && !_showDetails,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _showDetails && !_sending) _back();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _back),
        title: const Text('Nouveau signalement'),
      ),
      body: SafeArea(
        bottom: false,
        child: PageList(
          controller: _scroll,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 10,
              runSpacing: 8,
              children: [
                _StepLabel('1', 'Photo & Catégorie', active: !_showDetails),
                _StepLabel('2', 'Détails & Lieu', active: _showDetails),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _showDetails ? 1 : .5,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
            if (_showDetails) _detailsStep(context) else _photoStep(context),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 618),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _showDetails
                      ? (_sending || _locating ? null : _send)
                      : (_choosingPhoto ? null : _next),
                  icon: Icon(
                    _showDetails ? Icons.send_outlined : Icons.arrow_forward,
                    size: 18,
                  ),
                  label: WorkingLabel(
                    _showDetails ? 'Envoyer le signalement' : 'Continuer',
                    busy: _sending,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _StepLabel extends StatelessWidget {
  const _StepLabel(this.number, this.label, {required this.active});
  final String number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 12,
        backgroundColor: active ? civicBlue : civicTint,
        foregroundColor: active ? Colors.white : civicBlue,
        child: Text(number, style: const TextStyle(fontSize: 12)),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: active ? civicBlue : civicMuted,
        ),
      ),
    ],
  );
}
