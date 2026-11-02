import 'package:flutter/material.dart';

import 'theme.dart';

/// Shared page sections: compact desktop panels, naturally stacked on phones.
class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel({
    super.key,
    required this.child,
    this.title,
    this.caption,
    this.trailing,
  });
  final Widget child;
  final String? title, caption;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(title!, style: Theme.of(context).textTheme.titleMedium),
                ?trailing,
              ],
            ),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(caption!, style: TextStyle(color: c.secondary)),
              ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

/// One visual contract for the existing reviewed, durable form controllers.
class WorkspaceForm extends StatelessWidget {
  const WorkspaceForm({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: WorkspacePanel(child: child),
    ),
  );
}

class WorkspaceSteps extends StatelessWidget {
  const WorkspaceSteps({super.key, required this.active});
  final int active;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Wrap(
      spacing: 20,
      runSpacing: 10,
      children: [
        for (final (index, label) in const [
          'Details',
          'Review',
          'Result',
        ].indexed)
          Semantics(
            selected: active == index,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: active == index
                      ? CraftTheme.of(context).selection
                      : CraftTheme.of(context).subtle,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      color: active == index
                          ? CraftTheme.of(context).primary
                          : CraftTheme.of(context).secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: active == index
                        ? CraftTheme.of(context).text
                        : CraftTheme.of(context).secondary,
                    fontWeight: active == index
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
