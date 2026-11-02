import 'package:flutter/widgets.dart';

import '../app/demo_routes.dart';
import '../finance/files_data.dart';
import '../gallery/settings.dart';
import '../life/life_hub.dart' show openLifeChecks;
import '../life/life_settings.dart';
import '../local/local_runtime.dart';
import '../prototype/scenarios.dart';
import '../shared/shared_hub.dart';
import 'profile_actions.dart';
import 'profile_data.dart';

/// Goes to a section's tab, closing the profile page first.
typedef ProfileGoTo = void Function(AppDestination destination, String? tab);

/// What Profile and settings shows and can do, whichever build is running.
class ProfileSource {
  const ProfileSource({
    required this.settings,
    required this.name,
    required this.profileId,
    required this.demo,
    required this.connected,
    required this.hidden,
    required this.syncLine,
    required this.rename,
    required this.togglePrivacy,
    required this.openLifeSettings,
    required this.openLifeChecks,
    required this.actions,
    required this.connection,
    required this.listenable,
    this.complete = true,
    this.reviews = const [],
    this.filesListed,
    this.needsReview = false,
    this.preferenceError,
    this.hub,
    this.goTo,
  });
  final GallerySettings settings;
  final String name, profileId;
  final bool demo, connected, hidden, needsReview, complete;

  /// The connection's state, in the words the title bar uses.
  final String syncLine;
  final String? preferenceError;
  final Future<void> Function(String name) rename;
  final VoidCallback togglePrivacy, openLifeSettings, openLifeChecks;
  final ProfileActions actions;
  final ConnectionFacts connection;
  final List<ReviewRow> reviews;

  /// How many files a backup would list.
  final int? filesListed;

  /// What changes this source, for a page opened from it.
  final Listenable listenable;
  final SharedHub? hub;
  final ProfileGoTo? goTo;
}

ProfileSource profileSource(
  BuildContext context,
  PrototypeSession session,
  GallerySettings settings, {
  required ProfileActions actions,
  required Listenable listenable,
  List<ReviewRow> demoReviews = const [],
  int? demoFiles,
  SharedHub? hub,
  ProfileGoTo? goTo,
}) {
  void lifeSettings() => openDemoPage<void>(
    context,
    LifeSettings(session: session),
    'life/help',
    title: 'Life preferences',
  );
  void lifeChecks() => openLifeChecks(context, session);
  final facts = actions.facts();
  if (session is LocalSession) {
    final connected = !session.local;
    final finance = session.localFinance;
    return ProfileSource(
      settings: settings,
      name: session.profile.name,
      profileId: session.profile.profileId,
      demo: false,
      connected: connected,
      hidden: session.hideAmounts,
      syncLine: connected ? session.syncLabel : 'On this device only',
      needsReview: session.needsReview,
      complete: session.complete,
      preferenceError: session.runtime.preferenceError,
      rename: session.runtime.rename,
      togglePrivacy: session.togglePrivacy,
      openLifeSettings: lifeSettings,
      openLifeChecks: lifeChecks,
      actions: actions,
      connection: facts,
      listenable: listenable,
      reviews: [
        for (final row in session.runtime.connected.reviews)
          reviewRow(
            row,
            hidden: session.hideAmounts,
            connected: facts.bound == 'connected',
            amount: session.amount,
            accountName: (id) =>
                finance.snapshot.accounts
                    .where((a) => a.id == id)
                    .firstOrNull
                    ?.name ??
                'Not available yet',
            categoryName: finance.categoryName,
          ),
      ],
      filesListed: FilesSummary(fileRows(finance.snapshot)).linked.length,
      hub: hub,
      goTo: goTo,
    );
  }
  return ProfileSource(
    settings: settings,
    name: session.profile.name,
    profileId: session.profile.profileId,
    demo: true,
    connected: facts.connected,
    hidden: session.hideAmounts,
    syncLine: phaseWords(facts).$1,
    needsReview: facts.toCheck > 0,
    complete: session.complete,
    rename: (name) async {
      // Kept in memory, like everything in the demo.
      session.profile.name = name.trim();
      session.profile.changed();
    },
    togglePrivacy: session.togglePrivacy,
    openLifeSettings: lifeSettings,
    openLifeChecks: lifeChecks,
    actions: actions,
    connection: facts,
    listenable: listenable,
    reviews: demoReviews,
    filesListed: demoFiles,
    hub: hub,
    goTo: goTo,
  );
}
