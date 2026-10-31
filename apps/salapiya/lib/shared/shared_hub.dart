import 'package:flutter/widgets.dart';

import '../local/finance_domain.dart' show civilToday;
import '../local/local_runtime.dart';
import '../prototype/scenarios.dart';
import 'shared_data.dart';
import 'shared_demo.dart';
import 'shared_domain.dart';
import 'shared_pages.dart' show SharedPrivateActions;
import 'shared_repository.dart';
import 'shared_screen.dart' show SharedNativeForms;

/// What Shared Expenses is showing, kept outside the section's screen. The
/// shell keys that screen on its tab, so anything held there is lost on every
/// tab change: the repository would reload and the chosen group reset.
class SharedHub extends ChangeNotifier {
  SharedHub(this.session) {
    final session = this.session;
    if (session is LocalSession) {
      final repo = SharedRepository(
        session.runtime,
        session.localFinance.store,
      );
      this.repo = repo;
      private = SharedNativeForms(session, repo);
      repo
        ..addListener(notifyListeners)
        ..open();
    }
  }
  final PrototypeSession session;

  /// Null in the demo build.
  SharedRepository? repo;
  SharedPrivateActions? private;

  /// The group chosen this session. Null until the user picks one.
  String? selected;

  /// The user asked to see every group, even if one would open by itself.
  bool choosing = false;

  /// Opens Profile › Connection; the shell sets this.
  VoidCallback? openConnection;

  void choose(String id) {
    if (selected == id && !choosing) return;
    selected = id;
    choosing = false;
    notifyListeners();
  }

  void showChooser() {
    selected = null;
    choosing = true;
    notifyListeners();
  }

  String? get defaultGroup => session.sharedDefaultGroup;

  /// Saved with the profile's settings, so changing one can't lose the other.
  void setDefault(String? id) {
    session.sharedDefaultGroup = id;
    final local = session;
    if (local is LocalSession) local.runtime.settings.change(() {});
    notifyListeners();
  }

  /// The group to show, or null when the user should choose one. What was
  /// chosen this session comes first, then the default if it can still be
  /// used. An only group opens by itself: archived and left ones don't count.
  SharedGroup? group(SharedSource s) {
    if (choosing) return null;
    SharedGroup? byId(String? id) =>
        s.groups.where((g) => g.id == id).firstOrNull;
    final chosen = byId(selected);
    if (chosen != null) return chosen;
    final current = sharedGroupRows(s).where((r) => r.current).toList();
    final fallback = current.where((r) => r.group.id == defaultGroup);
    if (fallback.isNotEmpty) return fallback.first.group;
    if (current.length == 1) return current.single.group;
    return s.groups.length == 1 ? s.groups.single : null;
  }

  /// Shows the group with a payment waiting for the user. The count people
  /// follow here covers every group, so the one on show may have none.
  void focusWaiting() {
    final row = sharedGroupRows(source()).where((r) => r.toConfirm > 0);
    if (row.isNotEmpty) choose(row.first.group.id);
    // Nothing to confirm: a default or an only group still opens as usual.
  }

  SharedSource source() {
    final repo = this.repo;
    if (repo == null) return demoSharedSource(session);
    final local = session as LocalSession;
    final connected = repo.actor != null;
    return SharedSource(
      today: civilToday(),
      groups: repo.groups,
      loaded: repo.loaded,
      connected: connected,
      online: connected && repo.online,
      complete: session.complete,
      hidden: session.hideAmounts,
      amount: session.amount,
      writer: repo,
      profileName: session.profile.name,
      actor: repo.actor,
      intents: repo.intents,
      drafts: repo.drafts,
      reviews: repo.reviews,
      current: local.localFinance.snapshot.current,
      error: repo.error,
      pendingCount: local.runtime.connected.sharedPendingCount,
      needsReview: session.needsReview,
      syncLabel: session.syncLabel,
      onReview: openConnection,
      onConnect: openConnection,
    );
  }

  @override
  void dispose() {
    repo?.removeListener(notifyListeners);
    repo?.dispose();
    super.dispose();
  }
}

/// Lets the record page and Money's share flow reach Shared Expenses.
class SharedScope extends InheritedNotifier<SharedHub> {
  const SharedScope({super.key, required SharedHub hub, required super.child})
    : super(notifier: hub);
  static SharedHub? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SharedScope>()?.notifier;
}
