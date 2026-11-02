import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../finance/debt_cards.dart' show civilDay;
import 'shared_cards.dart';
import 'shared_data.dart';
import 'shared_domain.dart';
import 'shared_people_data.dart';

/// "What can I do to this group as a whole, and what will that do?" Only what
/// the server allows the user now is listed, with what each one does. The
/// confirmations say what changes and what stays.
class SharedLifecycleTab extends StatelessWidget {
  const SharedLifecycleTab({
    super.key,
    required this.source,
    required this.group,
    required this.onTransfer,
    required this.onRemove,
    required this.onArchive,
    required this.onLeave,
    required this.onTask,
  });
  final SharedSource source;
  final SharedGroup group;
  final VoidCallback onTransfer, onRemove, onArchive, onLeave;
  final ValueChanged<SharedTask> onTask;

  @override
  Widget build(BuildContext context) {
    final android = !isDesktop(context);
    final g = group, me = g.participant(source.actor ?? '');
    final choices = groupChoices(g, me);
    final can = _CanCard(
      group: g,
      me: me,
      choices: choices,
      onTransfer: onTransfer,
      onRemove: onRemove,
      onArchive: onArchive,
      onLeave: onLeave,
    );
    final about = _AboutCard(group: g, me: me);
    final tasks = source.complete
        ? sharedTasks(source, g, scope: SharedTaskScope.group)
        : const <SharedTask>[];
    final work = tasks.isEmpty
        ? null
        : SharedTasksCard(
            tasks: tasks,
            onOpen: onTask,
            title: 'Waiting or refused',
          );
    return DashboardGrid(
      key: const ValueKey('shared-lifecycle-grid'),
      cards: android
          ? null
          : [
              (can, 7, 12),
              (about, 5, 12),
              ?(work == null ? null : (work, 12, 12)),
            ],
      stacked: [?work, can, about],
    );
  }
}

class _CanCard extends StatelessWidget {
  const _CanCard({
    required this.group,
    required this.me,
    required this.choices,
    required this.onTransfer,
    required this.onRemove,
    required this.onArchive,
    required this.onLeave,
  });
  final SharedGroup group;
  final String? me;
  final GroupChoices choices;
  final VoidCallback onTransfer, onRemove, onArchive, onLeave;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final g = group;
    final owner = g.data['owner'] as String?;
    final ownerGone = owner != null && g.people[owner]?['kind'] == 'deleted';
    final note = ownerGone
        ? 'The owner’s account was deleted, so this group stays archived. Nobody can restore it.'
        : choices.mustHandOver
        ? choices.transfer
              ? 'As the owner, you can’t leave. Make someone else the owner first.'
              : 'As the owner, you can’t leave. Someone with an account has to join first, or you can archive the group.'
        : !choices.any
        ? null
        : 'Only the owner can change the group. If they’re away, everyone can still add bills, and nobody can take over as owner.';
    return OverviewCard(
      key: const ValueKey('lifecycle-can'),
      title: 'What you can do',
      caption: 'All of these need a connection',
      child: !choices.any
          ? const EmptyState(
              icon: Icons.logout,
              title: 'You’ve left this group',
              message: 'Your earlier records stay here. To come back, ask the owner for a new invitation.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListGroup(
                  leading: true,
                  children: [
                    if (choices.transfer)
                      AdaptiveRow(
                        key: const ValueKey('lifecycle-transfer'),
                        leading: Icons.swap_horiz,
                        title: 'Make someone else the owner',
                        subtitle: 'They run the group and you become a member.',
                        onTap: onTransfer,
                      ),
                    if (choices.remove)
                      AdaptiveRow(
                        key: const ValueKey('lifecycle-remove'),
                        leading: Icons.person_remove_outlined,
                        title: 'Remove someone',
                        subtitle:
                            'They can’t add anything. Their balance stays.',
                        onTap: onRemove,
                      ),
                    if (choices.archive)
                      AdaptiveRow(
                        key: const ValueKey('lifecycle-archive'),
                        leading: Icons.inventory_2_outlined,
                        title: 'Archive this group',
                        subtitle: 'Nobody can add bills. Everything stays.',
                        onTap: onArchive,
                      ),
                    if (choices.restore)
                      AdaptiveRow(
                        key: const ValueKey('lifecycle-restore'),
                        leading: Icons.unarchive_outlined,
                        title: 'Restore this group',
                        subtitle: 'People can add bills and payments again.',
                        onTap: onArchive,
                      ),
                    if (choices.leave)
                      AdaptiveRow(
                        key: const ValueKey('lifecycle-leave'),
                        leading: Icons.logout,
                        title: 'Leave this group',
                        subtitle: 'You can’t add anything. Your balance stays.',
                        onTap: onLeave,
                      ),
                  ],
                ),
                if (note != null) ...[
                  const SizedBox(height: Space.sm),
                  Text(
                    note,
                    key: const ValueKey('lifecycle-note'),
                    style: text.bodySmall?.copyWith(color: c.secondary),
                  ),
                ],
                const ListEnd(key: ValueKey('lifecycle-can-end')),
              ],
            ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.group, required this.me});
  final SharedGroup group;
  final String? me;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final owner = g.data['owner'] as String?;
    final joined = me == null ? null : sharedMember(g, me!);
    final started = [
      for (final e in g.data['activity'] as List)
        if (e['op'] == 'create') civilDayOf(e['at'] as String?),
    ].firstOrNull;
    return OverviewCard(
      key: const ValueKey('lifecycle-about'),
      title: 'This group',
      caption: 'Leaving or archiving never erases records or clears balances',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FactRow(
            'Status',
            !g.active(me)
                ? 'You’ve left'
                : g.archived
                ? 'Archived'
                : 'Active',
          ),
          if (owner != null) FactRow('Owner', personLabel(g, owner, me)),
          if (joined != null && g.active(me))
            FactRow('You’re', joined.role.label),
          FactRow('People', '${g.people.length}'),
          if (started != null) FactRow('Started', civilDay(started)),
          const ListEnd(key: ValueKey('lifecycle-about-end')),
        ],
      ),
    );
  }
}
