import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../finance/debt_cards.dart' show civilDay;
import 'shared_cards.dart';
import 'shared_data.dart';
import 'shared_domain.dart';
import 'shared_hub.dart';
import 'shared_pages.dart';
import 'shared_private_data.dart';
import 'shared_records_tab.dart';

/// One bill, payment or refund against the user's own record: what the group
/// says beside what their record says, and what they can do about it. Only
/// the user can see this, and only their own records are read.
class SharedRecordPage extends StatelessWidget {
  const SharedRecordPage({
    super.key,
    required this.hub,
    required this.group,
    required this.kind,
    required this.id,
  });
  final SharedHub hub;
  final String group, id;
  final PrivateKind kind;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([hub, hub.session]),
    builder: (context, _) {
      final source = hub.source();
      final g = source.groups.where((x) => x.id == group).firstOrNull;
      final me = g?.participant(source.actor ?? '');
      final row = g == null
          ? null
          : privateRows(
              g,
              me,
              source.current,
              source.reviews,
              source.today,
            ).where((r) => r.kind == kind && r.id == id).firstOrNull;
      if (g == null || row == null) {
        return sharedGonePage('My record', 'My Records');
      }
      return _RecordPage(hub: hub, source: source, g: g, r: row);
    },
  );
}

class _RecordPage extends StatelessWidget {
  const _RecordPage({
    required this.hub,
    required this.source,
    required this.g,
    required this.r,
  });
  final SharedHub hub;
  final SharedSource source;
  final SharedGroup g;
  final PrivateRow r;

  @override
  Widget build(BuildContext context) {
    final flows = SharedFlows(hub);
    final a = source.amount;
    final record = r.record;
    String shown(BigInt? value) => value == null ? '—' : a(value);
    BigInt? stored(String key) => typedAmount(record?.values[key]);
    final compare = OverviewCard(
      key: const ValueKey('record-compare'),
      title: 'The group and my record',
      caption: r.gone || r.state.needsYou
          ? privateNote(r)
          : 'Only you can see your record',
      accent: true,
      child: SharedMoneyTable(
        key: const ValueKey('record-table'),
        label: '',
        columns: const ['The group', 'My record'],
        rows: switch (r.kind) {
          PrivateKind.bill => [
            ('You paid', [shown(r.paid), shown(stored('fundingAmount'))]),
            ('Your part', [shown(r.part), shown(stored('shareAmount'))]),
          ],
          PrivateKind.refund => [
            ('Came back to you', [shown(r.paid), shown(stored('fundingAmount'))]),
            ('Your part went down', [shown(r.part), shown(stored('shareAmount'))]),
          ],
          PrivateKind.payment => [
            ('Amount', [shown(r.group), shown(stored('fundingAmount'))]),
          ],
        },
      ),
    );
    final account = source.accountName?.call(record?.values['account'] ?? '');
    final about = OverviewCard(
      key: const ValueKey('record-about'),
      title: 'About my record',
      caption: 'Only you can see this',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FactRow('Where it stands', r.state.label),
          FactRow('Type', r.kind.label),
          FactRow('Date', civilDay(record?.date ?? r.date)),
          if (account != null) FactRow('Account', account),
          if (record == null)
            const FactRow('My Money', 'Unchanged. Adding it is up to you.'),
        ],
      ),
    );
    final checks = [
      for (final x in reviewsFor(source.reviews, g.id))
        if (x['bill_id'] == r.id && r.kind == PrivateKind.bill) x,
    ];
    final history = checks.isEmpty
        ? null
        : OverviewCard(
            key: const ValueKey('record-checks'),
            title: 'What you’ve checked',
            caption: 'Your own notes. The group doesn’t see them.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListGroup(children: [for (final x in checks) reviewRow(g, x)]),
                const ListEnd(),
              ],
            ),
          );
    final me = g.participant(source.actor ?? '');
    final canAdd = !r.gone && (g.active(me) || record != null);
    void private(String mode) => flows.private(
      context,
      (forms) => forms.privateEffect(context, g, r.id, mode),
    );
    return SectionPage(
      title: r.title,
      caption: '${r.kind.label} · ${civilDay(r.date)} · ${g.name}',
      status: privatePill(r.state),
      actions: [
        if (r.state == PrivateState.toCount)
          AppButton(
            'Count it in my group balance',
            key: const ValueKey('record-count'),
            onPressed: () => private('clear'),
          )
        else if (r.state == PrivateState.toTakeOut)
          AppButton(
            'Take it out of my group balance',
            key: const ValueKey('record-take-out'),
            onPressed: () => private('unclear'),
          )
        else if (canAdd)
          AppButton(
            record == null ? 'Add to my Money' : 'Review my record',
            key: const ValueKey('record-review'),
            onPressed: () => private(r.kind.name),
          ),
        if (r.state == PrivateState.needsLook && !r.gone)
          billAction(
            'Keep my record as it is',
            key: const ValueKey('record-keep'),
            online: source.online,
            onPressed: () => flows.private(
              context,
              (forms) => forms.retainEvidence(context, g, r.id),
            ),
          ),
        if (!r.gone && r.kind != PrivateKind.payment)
          CardLink(
            'Open the bill',
            key: const ValueKey('record-open-bill'),
            onPressed: () => flows.openBill(context, g, r.bill ?? r.id),
          ),
        if (!r.gone && r.kind == PrivateKind.payment)
          CardLink(
            'Open the payment',
            key: const ValueKey('record-open-payment'),
            onPressed: () => flows.openPayment(context, g, r.id),
          ),
      ],
      child: DashboardGrid(
        cards: isDesktop(context)
            ? [(compare, 8, 12), (about, 4, 12), ?(history == null ? null : (history, 12, 12))]
            : null,
        stacked: [compare, about, ?history],
      ),
    );
  }
}
