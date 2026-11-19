import 'dart:convert';

import 'package:flutter/material.dart';

import 'report_photo_web.dart' if (dart.library.io) 'report_photo_native.dart';

class ReportPhoto extends StatelessWidget {
  const ReportPhoto(this.photo, {super.key, this.fit = BoxFit.cover});
  final String photo;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(photo);
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
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFFECEEF0),
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}
