/// Starts the Android device UI. Engine, model credentials and subject state remain on the computer.
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'purrcept/app.dart';

/// Register native scanner notices, which Flutter's Dart package license collector does not own.
void main() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'ZXing Android Embedded',
      'ZXing Core',
    ], await rootBundle.loadString('assets/purrcept/qr_licenses.txt'));
  });
  runApp(const PurrceptApp());
}
