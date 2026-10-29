import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'app/title_bar.dart';
import 'design_system/kit/component_gallery.dart';

Future<void> main() async {
  // Debug-only component gallery: kDebugMode is a constant false in release
  // and profile builds, so this branch and the gallery are compiled out.
  if (kDebugMode && const bool.fromEnvironment('SALAPIYA_COMPONENTS')) {
    runApp(const ComponentGalleryApp());
    return;
  }
  // Windows: swap the native caption for the app's title bar before the
  // first frame. Elsewhere this does nothing.
  WidgetsFlutterBinding.ensureInitialized();
  await WindowFrame.enable();
  runApp(const SalapiyaApp(production: !bool.fromEnvironment('SALAPIYA_DEMO')));
}
