import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> savePhoto(
  String id,
  Uint8List bytes, {
  String? baseDirectory,
}) async {
  final documents = baseDirectory == null
      ? await getApplicationDocumentsDirectory()
      : Directory(baseDirectory);
  final directory = await Directory('${documents.path}/reports')
      .create(recursive: true);
  final file = File('${directory.path}/$id');
  await file.writeAsBytes(bytes, flush: true);
  return file.uri.toString();
}

Future<void> deletePhoto(String photo) async {
  final file = File.fromUri(Uri.parse(photo));
  if (await file.exists()) await file.delete();
}
