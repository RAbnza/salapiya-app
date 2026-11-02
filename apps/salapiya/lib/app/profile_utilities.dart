import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart' show RouteEscape;
import '../gallery/gallery.dart';
import '../gallery/settings.dart';
import '../profile/profile_actions.dart';
import '../profile/profile_page.dart';
import '../profile/profile_source.dart';
import '../prototype/scenarios.dart';
import '../shared/shared_hub.dart';

/// Profile and settings, on [tab]. The demo shows the same tabs as a real
/// profile, with its own tools on the Profile tab.
class ProfileUtilities extends StatelessWidget {
  const ProfileUtilities({
    super.key,
    required this.settings,
    required this.session,
    this.tab,
    this.hub,
    this.goTo,
    this.actions,
  });
  final GallerySettings settings;
  final PrototypeSession session;
  final ValueNotifier<String>? tab;
  final SharedHub? hub;
  final ProfileGoTo? goTo;
  final ProfileActions? actions;
  @override
  Widget build(BuildContext context) => ProfilePage(
    session: session,
    settings: settings,
    tab: tab,
    hub: hub,
    goTo: goTo,
    actions: actions,
  );
}

class GalleryUtility extends StatelessWidget {
  const GalleryUtility({super.key, required this.settings});
  final GallerySettings settings;
  @override
  Widget build(BuildContext context) => RouteEscape(
    child: Scaffold(
      appBar: AppBar(title: const Text('Design Gallery · utility')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (_, _) => GalleryHome(settings: settings),
      ),
    ),
  );
}
