import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart' show QuickAction;
import '../prototype/scenarios.dart';
import 'overview_dashboard.dart';

/// The Overview destination: the dashboard, for real profiles and the demo
/// build alike.
class Overview extends StatelessWidget {
  const Overview({
    super.key,
    required this.session,
    required this.open,
    this.actions = const [],
  });
  final PrototypeSession session;
  final ValueChanged<PreviewSource> open;

  /// Quick actions under the header.
  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) =>
      OverviewDashboard(session: session, open: open, actions: actions);
}
