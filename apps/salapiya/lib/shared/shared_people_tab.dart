import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../finance/debt_cards.dart' show civilDay;
import 'shared_cards.dart';
import 'shared_data.dart';
import 'shared_domain.dart';
import 'shared_people_data.dart';
import 'shared_person_pages.dart' show memberPill;

/// "Who's in this group, and what can each of them do?" Only what the server
/// allows the user now is offered, and nothing here moves money.
class SharedPeopleTab extends StatelessWidget {
  const SharedPeopleTab({
    super.key,
    required this.source,
    required this.group,
    required this.onPerson,
    required this.onAdd,
    required this.onInvite,
    required this.onRevoke,
    required this.onTask,
  });
  final SharedSource source;
  final SharedGroup group;
  final ValueChanged<String> onPerson;
  final VoidCallback onAdd, onInvite;
  final ValueChanged<OpenInvitation> onRevoke;
  final ValueChanged<SharedTask> onTask;

  @override
  Widget build(BuildContext context) {
    final android = !isDesktop(context);
    final g = group;
    final me = g.participant(source.actor ?? '');
    final choices = groupChoices(g, me);
    final everyone = _EveryoneCard(
      source: source,
      group: g,
      me: me,
      choices: choices,
      onPerson: onPerson,
      onAdd: onAdd,
      onInvite: onInvite,
    );
    final roles = _RolesCard(members: sharedMembers(g, me));
    final invitations = choices.addPeople
        ? _InvitationsCard(
            rows: openInvitations(g, source.intents, source.today),
            onInvite: onInvite,
            onRevoke: onRevoke,
          )
        : null;
    final tasks = source.complete
        ? sharedTasks(source, g, scope: SharedTaskScope.people)
        : const <SharedTask>[];
    final work = tasks.isEmpty
        ? null
        : SharedTasksCard(
            tasks: tasks,
            onOpen: onTask,
            title: 'Waiting or refused',
          );
    return DashboardGrid(
      key: const ValueKey('shared-people-grid'),
      cards: android
          ? null
          : [
              (everyone, 8, 12),
              (roles, 4, 12),
              ?(invitations == null
                  ? null
                  : (invitations, work == null ? 12 : 7, 12)),
              ?(work == null ? null : (work, invitations == null ? 12 : 5, 12)),
            ],
      stacked: [?work, everyone, roles, ?invitations],
    );
  }
}

class _EveryoneCard extends StatelessWidget {
  const _EveryoneCard({
    required this.source,
    required this.group,
    required this.me,
    required this.choices,
    required this.onPerson,
    required this.onAdd,
    required this.onInvite,
  });
  final SharedSource source;
  final SharedGroup group;
  final String? me;
  final GroupChoices choices;
  final ValueChanged<String> onPerson;
  final VoidCallback onAdd, onInvite;

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final g = group, amount = source.amount;
    final whole = source.complete && g.complete;
    final positions = whole ? guarded(g.positions) : null;
    final members = sharedMembers(g, me);
    String? stands(SharedMember m) {
      final p = positions?[m.person];
      return p == null ? null : standsWords(m.person, p, me, amount);
    }

    String name(SharedMember m) =>
        m.person == me ? '${m.name} (you)' : m.name;
    String details(SharedMember m) => detailLine([
      if (m.left != null)
        'Left ${civilDay(m.left!)}'
      else if (m.joined != null)
        'Joined ${civilDay(m.joined!)}',
      if (m.joined == null && m.left == null) 'Added by the owner',
    ]);
    return OverviewCard(
      key: const ValueKey('people-everyone'),
      title: 'Everyone in this group',
      caption: '${members.length} ${members.length == 1 ? 'person' : 'people'}',
      trailing: choices.addPeople
          ? Wrap(
              spacing: Space.md,
              children: [
                CardLink(
                  'Add a person',
                  key: const ValueKey('people-add'),
                  onPressed: onAdd,
                ),
                CardLink(
                  'Invite someone',
                  key: const ValueKey('people-invite'),
                  onPressed: onInvite,
                ),
              ],
            )
          : null,
      stackBelow: periodBase + rowBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTable(
            key: const ValueKey('people-table'),
            columns: const [
              (label: 'Person', flex: 3, width: null),
              (label: 'Role', flex: 2, width: null),
            ],
            moneyColumns: const ['Where they stand'],
            rows: [
              for (final m in members)
                AppTableRow(
                  id: m.person,
                  money: [stands(m)],
                  spoken: [
                    name(m),
                    !m.active && m.role != MemberRole.deleted
                        ? 'Left'
                        : m.role.label,
                    details(m),
                    stands(m) ?? MoneyAmount.unknown,
                  ].join(', '),
                  onTap: () => onPerson(m.person),
                  cells: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name(m), style: text.titleSmall),
                        Text(
                          details(m),
                          style: text.bodySmall?.copyWith(color: c.secondary),
                        ),
                      ],
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: memberPill(m),
                    ),
                  ],
                  narrow: AdaptiveRow(
                    key: ValueKey('person-${m.person}'),
                    title: name(m),
                    // "Left 19 Sep 2026" already says it.
                    subtitle: detailLine([
                      if (m.active || m.role == MemberRole.deleted)
                        m.role.label,
                      details(m),
                    ]),
                    trailing: MoneyAmount(stands(m)),
                    onTap: () => onPerson(m.person),
                  ),
                ),
            ],
          ),
          const ListEnd(key: ValueKey('people-end')),
        ],
      ),
    );
  }
}

/// What each kind of person can do, for the kinds in this group.
class _RolesCard extends StatelessWidget {
  const _RolesCard({required this.members});
  final List<SharedMember> members;

  @override
  Widget build(BuildContext context) {
    final seen = <String, String>{};
    for (final m in members) {
      final label = !m.active && m.role != MemberRole.deleted
          ? 'Left'
          : m.role.label;
      seen[label] ??= m.can;
    }
    return OverviewCard(
      key: const ValueKey('people-roles'),
      title: 'What each can do',
      caption: 'Nobody can see anyone’s accounts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in seen.entries) FactRow(e.key, e.value),
          const ListEnd(key: ValueKey('people-roles-end')),
        ],
      ),
    );
  }
}

/// Invitations that may still be open.
class _InvitationsCard extends StatelessWidget {
  const _InvitationsCard({
    required this.rows,
    required this.onInvite,
    required this.onRevoke,
  });
  final List<OpenInvitation> rows;
  final VoidCallback onInvite;
  final ValueChanged<OpenInvitation> onRevoke;

  @override
  Widget build(BuildContext context) => OverviewCard(
    key: const ValueKey('people-invitations'),
    title: 'Invitations',
    caption: 'Sent in the last seven days. One that’s been used shows here too.',
    child: rows.isEmpty
        ? EmptyState(
            icon: Icons.mail_outline,
            title: 'No invitations out',
            message: 'Invite someone by their Google account.',
            action: AppButton.secondary(
              'Invite someone',
              key: const ValueKey('people-invite-first'),
              onPressed: onInvite,
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListGroup(
                children: [
                  for (final r in rows)
                    AdaptiveRow(
                      key: ValueKey('invitation-${r.id}'),
                      title: r.email ?? 'An invitation',
                      subtitle: detailLine([
                        'Sent ${civilDay(r.sent)}',
                        'Ends ${civilDay(r.expires)}',
                      ]),
                      trailing: CardLink(
                        'Revoke',
                        key: ValueKey('revoke-${r.id}'),
                        chevron: false,
                        onPressed: () => onRevoke(r),
                      ),
                    ),
                ],
              ),
              const ListEnd(key: ValueKey('people-invitations-end')),
            ],
          ),
  );
}
