import 'dart:convert';
import 'dart:typed_data';

Future<String> savePhoto(
  String id,
  Uint8List bytes, {
  String? baseDirectory,
}) async => 'data:application/octet-stream;base64,${base64Encode(bytes)}';

Future<void> deletePhoto(String photo) async {}
