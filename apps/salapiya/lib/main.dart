import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'design_system/kit/component_gallery.dart';

void main() {
  // Debug-only component gallery: kDebugMode is a constant false in release
  // and profile builds, so this branch and the gallery are compiled out.
  if (kDebugMode && const bool.fromEnvironment('SALAPIYA_COMPONENTS')) {
    runApp(const ComponentGalleryApp());
    return;
  }
  runApp(const SalapiyaApp(production: !bool.fromEnvironment('SALAPIYA_DEMO')));
}
