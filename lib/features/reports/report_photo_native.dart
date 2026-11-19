import 'dart:io';

import 'package:flutter/widgets.dart';

ImageProvider localPhoto(Uri uri) => FileImage(File.fromUri(uri));
