import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../local/local_runtime.dart';
import '../profile/profile_page.dart';
import '../shared/shared_hub.dart';

/// The profile's Connection tab, wherever a link to it comes from: the
/// shell's own page when there is one.
void openConnection(BuildContext context, LocalRuntime runtime) {
  final open = SharedScope.maybeOf(context)?.openConnection;
  if (open != null) {
    open();
    return;
  }
  openDemoPage<void>(context, ConnectionPage(runtime: runtime), 'profile');
}

class ConnectionPage extends StatelessWidget {
  const ConnectionPage({super.key, required this.runtime});
  final LocalRuntime runtime;
  @override
  Widget build(BuildContext context) => ProfilePage(
    session: runtime.session!,
    settings: runtime.settings,
    tab: ValueNotifier('Connection'),
  );
}
