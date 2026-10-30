import 'package:flutter/material.dart';

import '../design_system/components.dart';
import '../design_system/editorial.dart';
import '../design_system/kit/kit.dart' show QuickAction;
import '../design_system/theme.dart';
import '../prototype/scenarios.dart';
import 'overview_dashboard.dart';

class SourceLink extends StatelessWidget {
  const SourceLink({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.trailing,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? trailing;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextButton(
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: CraftTheme.of(context).text,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(
              icon,
              color: CraftTheme.of(context).dark ? Palette.lilac : Palette.mint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: CraftTheme.of(context).secondary,
                    ),
                  ),
                  if (trailing != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: AmountText(trailing!),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.north_east, size: 16),
          ],
        ),
      ),
      Divider(height: 1, color: CraftTheme.of(context).divider),
    ],
  );
}

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
