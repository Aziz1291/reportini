import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'report_photo_web.dart' if (dart.library.io) 'report_photo_native.dart';

class ReportPhoto extends StatelessWidget {
  const ReportPhoto(this.photo, {super.key, this.fit = BoxFit.cover});
  final String photo;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(photo);
    if (uri?.scheme == 'gs') {
      return _FirebasePhoto(photo, key: ValueKey(photo), fit: fit);
    }
    final ImageProvider provider = switch (uri?.scheme) {
      'data' => MemoryImage(
        base64Decode(photo.substring(photo.indexOf(',') + 1)),
      ),
      'http' || 'https' => NetworkImage(photo),
      'file' => localPhoto(uri!),
      _ => AssetImage(photo),
    };
    return Image(
      image: provider,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      semanticLabel: 'Photo du constat',
      errorBuilder: (_, _, _) => const _UnavailablePhoto(),
    );
  }
}

class _FirebasePhoto extends StatefulWidget {
  const _FirebasePhoto(this.url, {super.key, required this.fit});
  final String url;
  final BoxFit fit;

  @override
  State<_FirebasePhoto> createState() => _FirebasePhotoState();
}

class _FirebasePhotoState extends State<_FirebasePhoto> {
  late final _bytes = FirebaseStorage.instance
      .refFromURL(widget.url)
      .getData(10 * 1024 * 1024);

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.data case final bytes?) {
        return Image.memory(
          bytes,
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
          semanticLabel: 'Photo du constat',
          errorBuilder: (_, _, _) => const _UnavailablePhoto(),
        );
      }
      return snapshot.connectionState == ConnectionState.waiting
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : const _UnavailablePhoto();
    },
  );
}

class _UnavailablePhoto extends StatelessWidget {
  const _UnavailablePhoto();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFECEEF0),
    child: Center(child: Icon(Icons.broken_image_outlined)),
  );
}
