import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../finance/debt_cards.dart' show civilDay, civilMonth;
import '../finance/money_cards.dart' show signedAmount;
import 'shared_balances_tab.dart' show balancesUnavailable;
import 'shared_cards.dart';
import 'shared_data.dart';
import 'shared_domain.dart';
import 'shared_hub.dart';
import 'shared_pages.dart';
import 'shared_people_data.dart';

/// The pages Balances and People open: one person, two people, and the lists
/// made to show someone else (§2 Shareable views). Each reads the hub again
/// when it changes.

/// A small heading over a list inside a shareable card.
Widget _listHeading(BuildContext context, String label) {
  final c = CraftTheme.of(context);
  return Padding(
    padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xs),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.text),
    ),
  );
}

/// "12 Oct", for a table's date column.
String _shortDate(String date) =>
    '${civilMonth(date)} ${DateTime.parse(date).day}';

/// Everything between two people, with the running net (DOMAIN_RULES §17–18).
/// [list] is the shareable version: one heading, the totals and every item,
/// with no actions.
class SharedPairPage extends StatelessWidget {
  const SharedPairPage({
    super.key,
    required this.hub,
    required this.group,
    required this.a,
    required this.b,
    this.list = false,
  });
  final SharedHub hub;
  final String group, a, b;
  final bool list;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([hub, hub.session]),
    builder: (context, _) {
      final source = hub.source();
      final g = source.groups.where((x) => x.id == group).firstOrNull;
      if (g == null || !g.people.containsKey(a) || !g.people.containsKey(b)) {
        return sharedGonePage('Between two people', 'Balances');
      }
      return _PairPage(hub: hub, source: source, g: g, a: a, b: b, list: list);
    },
  );
}

class _PairPage extends StatelessWidget {
  const _PairPage({
    required this.hub,
    required this.source,
    required this.g,
    required this.a,
    required this.b,
    required this.list,
  });
  final SharedHub hub;
  final SharedSource source;
  final SharedGroup g;
  final String a, b;
  final bool list;

  @override
  Widget build(BuildContext context) {
    final flows = SharedFlows(hub);
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final amount = source.amount, me = g.participant(source.actor ?? '');
    final title = a == me
        ? 'You and ${g.personName(b)}'
        : '${g.personName(a)} and ${g.personName(b)}';
    final pair = source.complete ? pairBreakdown(g, a, b, me, source.today) : null;
    String words(BigInt net) => net > BigInt.zero
        ? owesWords(g, a, b, me)
        : net < BigInt.zero
        ? owesWords(g, b, a, me)
        : a == me
        ? 'Nothing between you'
        : 'Nothing between them';
    /// The running figure in words, so a row never reads "You owe −₱5.00".
    String soFar(BigInt net) => net == BigInt.zero
        ? 'All square so far'
        : '${words(net)} ${amount(net.abs())}';
    String mid(String words) =>
        words.startsWith('You ') ? 'you ${words.substring(4)}' : words;
    final explain =
        'Above zero, ${mid(owesWords(g, a, b, me))}. Below zero, ${mid(owesWords(g, b, a, me))}.';
    Widget total(PairBreakdown p) => Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: LabelAmount(
        key: const ValueKey('pair-total'),
        label: Text(words(p.net), style: text.titleSmall),
        amount: MoneyAmount(amount(p.net.abs())),
      ),
    );
    Widget table(PairBreakdown p) => AppTable(
      key: const ValueKey('pair-table'),
      dense: list,
      columns: const [
        (label: 'Date', flex: 0, width: dateColumn),
        (label: 'What', flex: 1, width: null),
      ],
      moneyColumns: const ['Change', 'So far'],
      rows: [
        for (final r in p.rows)
          () {
            final change = signedAmount(r.change, amount, hidden: source.hidden);
            final net = signedAmount(r.net, amount, hidden: source.hidden);
            void open() => r.kind == PairRowKind.bill
                ? flows.openBill(context, g, r.id)
                : flows.openPayment(context, g, r.id);
            return AppTableRow(
              id: r.id,
              money: [change, net],
              spoken: [
                r.title,
                civilDay(r.date),
                if (r.detail.isNotEmpty) r.detail,
                'Change $change',
                soFar(r.net),
              ].join(', '),
              onTap: list ? null : open,
              cells: [
                Text(
                  _shortDate(r.date),
                  style: text.bodySmall?.copyWith(color: c.secondary),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(r.title, style: text.titleSmall),
                    if (r.detail.isNotEmpty)
                      Text(
                        r.detail,
                        style: text.bodySmall?.copyWith(color: c.secondary),
                      ),
                  ],
                ),
              ],
              narrow: AdaptiveRow(
                key: ValueKey('pair-row-${r.id}'),
                title: r.title,
                subtitle: detailLine([
                  civilDay(r.date),
                  if (r.detail.isNotEmpty) r.detail,
                  soFar(r.net),
                ]),
                trailing: MoneyAmount(change),
                onTap: list ? null : open,
              ),
            );
          }(),
      ],
    );
    Widget notCounted(PairBreakdown p) => ListGroup(
      children: [
        for (final n in p.notCounted)
          AdaptiveRow(
            key: ValueKey('pair-waiting-${n.id}'),
            title: n.who,
            subtitle: detailLine([civilDay(n.date), paymentStatusLabel(n)]),
            trailing: MoneyAmount(amount(n.amount)),
            onTap: list ? null : () => flows.openPayment(context, g, n.id),
          ),
      ],
    );
    if (list) {
      return SectionPage(
        title: title,
        caption: g.name,
        child: OverviewCard(
          key: const ValueKey('shared-list'),
          title: 'All dates',
          caption: 'As of ${civilDay(source.today)} · Confirmed payments only',
          child: pair == null
              ? balancesUnavailable(source)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StatStrip(
                      stats: [
                        (
                          label: words(pair.net),
                          value: amount(pair.net.abs()),
                          detail: null,
                        ),
                        (label: 'Bills', value: '${pair.bills}', detail: null),
                        (
                          label: 'Payments',
                          value: '${pair.payments}',
                          detail: null,
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                    Text(
                      explain,
                      style: text.bodySmall?.copyWith(color: c.secondary),
                    ),
                    if (pair.rows.isNotEmpty) ...[
                      const SizedBox(height: Space.sm),
                      table(pair),
                    ],
                    total(pair),
                    if (pair.notCounted.isNotEmpty) ...[
                      _listHeading(context, 'Not counted'),
                      notCounted(pair),
                    ],
                    const ListEnd(),
                  ],
                ),
        ),
      );
    }
    final net = pair?.net ?? BigInt.zero;
    final hero = OverviewCard(
      key: const ValueKey('pair-net'),
      title: a == me ? 'Between you' : 'Between them',
      caption: 'Confirmed payments only',
      accent: true,
      centered: true,
      corner: pair == null
          ? null
          : CardMenu(
              key: const ValueKey('pair-menu'),
              tooltip: 'More',
              items: [
                MenuItemButton(
                  key: const ValueKey('pair-page'),
                  leadingIcon: const Icon(Icons.open_in_new),
                  onPressed: () => flows.openPair(context, g, a, b, list: true),
                  child: const Text('Open as a list'),
                ),
              ],
            ),
      child: pair == null
          ? balancesUnavailable(source)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MoneyAmount(
                  net == BigInt.zero ? words(net) : amount(net.abs()),
                  kind: net == BigInt.zero
                      ? MoneyKind.neutral
                      : (net > BigInt.zero ? a : b) == me
                      ? MoneyKind.owed
                      : (net > BigInt.zero ? b : a) == me
                      ? MoneyKind.owedToYou
                      : MoneyKind.neutral,
                  size: MoneySize.tile,
                  textAlign: TextAlign.start,
                ),
                if (net != BigInt.zero)
                  Text(
                    words(net),
                    style: text.labelMedium?.copyWith(color: c.text),
                  ),
                if (pair.projected != net) ...[
                  const SizedBox(height: Space.sm),
                  FactRow(
                    'If waiting payments are confirmed',
                    pair.projected == BigInt.zero
                        ? words(pair.projected)
                        : '${words(pair.projected)} ${amount(pair.projected.abs())}',
                  ),
                ],
                const SizedBox(height: Space.sm),
                StatStrip(
                  stats: [
                    (label: 'Bills', value: '${pair.bills}', detail: null),
                    (
                      label: 'Payments',
                      value: '${pair.payments}',
                      detail: null,
                    ),
                  ],
                ),
              ],
            ),
    );
    final statement = pair == null
        ? null
        : OverviewCard(
            key: const ValueKey('pair-statement'),
            title: 'Every bill and payment',
            caption: explain,
            child: pair.rows.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Nothing between them yet',
                    message: 'Bills and payments they share show here.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [table(pair), total(pair), const ListEnd()],
                  ),
          );
    final waiting = pair == null || pair.notCounted.isEmpty
        ? null
        : OverviewCard(
            key: const ValueKey('pair-not-counted'),
            title: 'Not counted',
            caption: 'Waiting, disputed, cancelled or reversed',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [notCounted(pair), const ListEnd()],
            ),
          );
    final debtor = net > BigInt.zero ? a : b, creditor = net > BigInt.zero ? b : a;
    final canLog =
        pair != null &&
        net != BigInt.zero &&
        source.complete &&
        cantAdd(source, g) == null &&
        canLogFor(g, debtor, me);
    return SectionPage(
      title: title,
      caption: g.name,
      actions: [
        if (canLog)
          AppButton(
            'Log payment',
            key: const ValueKey('pair-log'),
            icon: Icons.payments_outlined,
            onPressed: () =>
                flows.logPayment(context, g, sender: debtor, recipient: creditor),
          ),
      ],
      child: DashboardGrid(
        cards: isDesktop(context)
            ? [
                (hero, waiting == null ? 12 : 8, 12),
                ?(waiting == null ? null : (waiting, 4, 12)),
                ?(statement == null ? null : (statement, 12, 12)),
              ]
            : null,
        stacked: [hero, ?statement, ?waiting],
      ),
    );
  }
}

/// A role as a pill: an icon and words, never color alone.
Widget memberPill(SharedMember m) => !m.active && m.role != MemberRole.deleted
    ? const StatusPill('Left', icon: Icons.logout)
    : StatusPill(
        m.role.label,
        icon: switch (m.role) {
          MemberRole.owner => Icons.verified_user_outlined,
          MemberRole.member => Icons.person_outline,
          MemberRole.notRegistered => Icons.person_off_outlined,
          MemberRole.deleted => Icons.no_accounts_outlined,
        },
        tone: m.role == MemberRole.owner
            ? PillTone.information
            : PillTone.neutral,
      );

/// One person: how their balance adds up, their bills and payments, and
/// their history in the group (DOMAIN_RULES §47). [list] is the shareable
/// version, with no actions.
class SharedPersonPage extends StatelessWidget {
  const SharedPersonPage({
    super.key,
    required this.hub,
    required this.group,
    required this.person,
    this.list = false,
  });
  final SharedHub hub;
  final String group, person;
  final bool list;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([hub, hub.session]),
    builder: (context, _) {
      final source = hub.source();
      final g = source.groups.where((x) => x.id == group).firstOrNull;
      if (g == null || !g.people.containsKey(person)) {
        return sharedGonePage('Person', 'People');
      }
      return _PersonPage(
        hub: hub,
        source: source,
        g: g,
        person: person,
        list: list,
      );
    },
  );
}

class _PersonPage extends StatelessWidget {
  const _PersonPage({
    required this.hub,
    required this.source,
    required this.g,
    required this.person,
    required this.list,
  });
  final SharedHub hub;
  final SharedSource source;
  final SharedGroup g;
  final String person;
  final bool list;

  @override
  Widget build(BuildContext context) {
    final flows = SharedFlows(hub);
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final amount = source.amount, me = g.participant(source.actor ?? '');
    final m = sharedMember(g, person);
    final you = person == me;
    final loaded = source.complete;
    final b = loaded ? personBreakdown(g, person) : null;
    final bills = loaded ? personBills(g, person) : const <PersonBill>[];
    final payments = loaded
        ? [
            for (final p in sharedPaymentRows(g, me, source.today))
              if (p.sender == person || p.recipient == person) p,
          ]
        : const <SharedPaymentRow>[];
    String words(BigInt position) => position > BigInt.zero
        ? (you ? 'You’re owed' : 'They’re owed')
        : position < BigInt.zero
        ? (you ? 'You owe the group' : 'They owe the group')
        : 'All square';
    Widget line(String label, BigInt value, {String? sign}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: LabelAmount(
        label: Text(label, style: text.bodyMedium),
        amount: MoneyAmount(
          source.hidden || sign == null || value == BigInt.zero
              ? amount(value)
              : '$sign${amount(value)}',
        ),
      ),
    );
    Widget adds(PersonBreakdown b) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line('Paid across bills', b.paid, sign: '+'),
        line(you ? 'Your part of bills' : 'Their part of bills', b.part, sign: '−'),
        line('Payments made, confirmed', b.sent, sign: '+'),
        line('Payments received, confirmed', b.received, sign: '−'),
        Divider(height: Space.sm, color: c.divider),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: LabelAmount(
            key: const ValueKey('person-position'),
            label: Text(words(b.position), style: text.titleSmall),
            amount: MoneyAmount(
              amount(b.position.abs()),
              kind: b.position == BigInt.zero || !you
                  ? MoneyKind.neutral
                  : b.position > BigInt.zero
                  ? MoneyKind.owedToYou
                  : MoneyKind.owed,
            ),
          ),
        ),
        if (b.waitingOut > BigInt.zero || b.waitingIn > BigInt.zero) ...[
          Divider(height: Space.sm, color: c.divider),
          Text(
            'Not counted until confirmed',
            style: text.labelMedium?.copyWith(color: c.secondary),
          ),
          if (b.waitingOut > BigInt.zero) line('Payments made', b.waitingOut),
          if (b.waitingIn > BigInt.zero)
            line('Payments received', b.waitingIn),
        ],
      ],
    );
    Widget billTable() => AppTable(
      key: const ValueKey('person-bills-table'),
      dense: list,
      columns: const [
        (label: 'Date', flex: 0, width: dateColumn),
        (label: 'Bill', flex: 1, width: null),
      ],
      moneyColumns: const ['Paid', 'Part'],
      rows: [
        for (final r in bills)
          AppTableRow(
            id: r.id,
            money: [amount(r.paid), amount(r.part)],
            spoken:
                '${r.name}, ${civilDay(r.date)}, paid ${amount(r.paid)}, part ${amount(r.part)}',
            onTap: list ? null : () => flows.openBill(context, g, r.id),
            cells: [
              Text(
                _shortDate(r.date),
                style: text.bodySmall?.copyWith(color: c.secondary),
              ),
              Text(r.name, style: text.titleSmall),
            ],
            narrow: AdaptiveRow(
              key: ValueKey('person-bill-${r.id}'),
              title: r.name,
              subtitle: detailLine([civilDay(r.date), 'Paid ${amount(r.paid)}']),
              trailing: MoneyAmount(amount(r.part)),
              onTap: list ? null : () => flows.openBill(context, g, r.id),
            ),
          ),
      ],
    );
    final name = you ? 'You' : g.personName(person);
    if (list) {
      return SectionPage(
        title: name,
        caption: g.name,
        child: OverviewCard(
          key: const ValueKey('shared-list'),
          title: 'All dates',
          caption: 'As of ${civilDay(source.today)} · Confirmed payments only',
          child: b == null
              ? balancesUnavailable(source)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    adds(b),
                    if (bills.isNotEmpty) ...[
                      _listHeading(context, 'Bills'),
                      billTable(),
                    ],
                    if (payments.isNotEmpty) ...[
                      _listHeading(context, 'Payments'),
                      paymentTable(context, g, payments, amount, null),
                    ],
                    const ListEnd(),
                  ],
                ),
        ),
      );
    }
    final balance = OverviewCard(
      key: const ValueKey('person-balance'),
      title: you ? 'How your balance adds up' : 'How their balance adds up',
      caption: 'Refunds applied · confirmed payments only',
      accent: true,
      corner: b == null
          ? null
          : CardMenu(
              key: const ValueKey('person-menu'),
              tooltip: 'More',
              items: [
                MenuItemButton(
                  key: const ValueKey('person-page'),
                  leadingIcon: const Icon(Icons.open_in_new),
                  onPressed: () =>
                      flows.openPerson(context, g, person, list: true),
                  child: const Text('Open as a list'),
                ),
              ],
            ),
      child: b == null ? balancesUnavailable(source) : adds(b),
    );
    final about = OverviewCard(
      key: const ValueKey('person-about'),
      title: 'About',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FactRow('Role', m.role.label),
          if (m.joined != null) FactRow('Joined', civilDay(m.joined!)),
          if (m.left != null) FactRow('Left', civilDay(m.left!)),
          FactRow('Can', m.can),
        ],
      ),
    );
    final billCard = OverviewCard(
      key: const ValueKey('person-bills'),
      title: 'Bills',
      caption: 'Newest first · refunds applied',
      child: !loaded
          ? balancesUnavailable(source)
          : bills.isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No bills yet',
              message: 'Bills this person is on show here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [billTable(), const ListEnd()],
            ),
    );
    final paymentCard = OverviewCard(
      key: const ValueKey('person-payments'),
      title: 'Payments',
      caption: 'Newest first',
      child: !loaded
          ? balancesUnavailable(source)
          : payments.isEmpty
          ? const EmptyState(
              icon: Icons.payments_outlined,
              title: 'No payments yet',
              message: 'Payments this person made or received show here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                paymentTable(
                  context,
                  g,
                  payments,
                  amount,
                  (p) => flows.openPayment(context, g, p.id),
                ),
                const ListEnd(),
              ],
            ),
    );
    final events = memberHistory(g, person);
    final history = OverviewCard(
      key: const ValueKey('person-history'),
      title: 'In this group',
      caption: 'Their place in the group over time',
      child: events.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'Nothing recorded',
              message: 'Added by the owner, with no account of their own.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListGroup(
                  children: [
                    for (final e in events)
                      AdaptiveRow(
                        title: e.title,
                        subtitle: detailLine([
                          if (e.date != null) civilDay(e.date!),
                          if ((e.reason ?? '').isNotEmpty) e.reason!,
                        ]),
                      ),
                  ],
                ),
                const ListEnd(),
              ],
            ),
    );
    final between = !you && me != null;
    final choices = memberChoices(g, me, person);
    return SectionPage(
      title: name,
      caption: [
        if (you) g.personName(person),
        g.name,
        if (m.joined != null) 'Joined ${civilDay(m.joined!)}',
      ].join(' · '),
      status: memberPill(m),
      actions: [
        if (between)
          AppButton.secondary(
            'Between you',
            key: const ValueKey('person-between'),
            icon: Icons.swap_horiz,
            onPressed: () => flows.openPair(context, g, me, person),
          ),
        if (choices.any)
          CardMenu(
            key: const ValueKey('person-actions'),
            tooltip: 'More',
            items: [
              if (choices.claim)
                MenuItemButton(
                  key: const ValueKey('person-claim'),
                  leadingIcon: const Icon(Icons.mail_outline),
                  onPressed: () => flows.invite(context, g, person: person),
                  child: const Text('Invite them to take this place'),
                ),
              if (choices.makeOwner)
                MenuItemButton(
                  key: const ValueKey('person-make-owner'),
                  leadingIcon: const Icon(Icons.swap_horiz),
                  onPressed: () => flows.transfer(context, g, person: person),
                  child: const Text('Make them the owner'),
                ),
              if (choices.remove)
                MenuItemButton(
                  key: const ValueKey('person-remove'),
                  leadingIcon: const Icon(Icons.person_remove_outlined),
                  onPressed: () => flows.remove(context, g, person: person),
                  child: const Text('Remove from group'),
                ),
            ],
          ),
      ],
      child: DashboardGrid(
        cards: isDesktop(context)
            ? [
                (balance, 8, 12),
                (about, 4, 12),
                (billCard, 12, 12),
                (paymentCard, 12, 12),
                (history, 12, 12),
              ]
            : null,
        stacked: [balance, about, billCard, paymentCard, history],
      ),
    );
  }
}

/// Where everyone stands and who owes whom, for one screenshot.
class SharedWhoOwesPage extends StatelessWidget {
  const SharedWhoOwesPage({super.key, required this.hub, required this.group});
  final SharedHub hub;
  final String group;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([hub, hub.session]),
    builder: (context, _) {
      final source = hub.source();
      final g = source.groups.where((x) => x.id == group).firstOrNull;
      if (g == null) return sharedGonePage('Who owes whom', 'Balances');
      final amount = source.amount, me = g.participant(source.actor ?? '');
      final whole = source.complete && g.complete;
      final positions = whole ? guarded(g.positions) : null;
      final rows = whole ? whoOwesRows(g, me) : const <SharedEdge>[];
      return SectionPage(
        title: 'Who owes whom',
        caption: g.name,
        child: OverviewCard(
          key: const ValueKey('shared-list'),
          title: 'Where it stands',
          caption: 'As of ${civilDay(source.today)} · Confirmed payments only',
          child: positions == null
              ? balancesUnavailable(source)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SharedMoneyTable(
                      key: const ValueKey('who-owes-people'),
                      label: 'Person',
                      columns: const ['Where they stand'],
                      rows: [
                        for (final p in positions.entries)
                          (
                            personLabel(g, p.key, me),
                            [standsWords(p.key, p.value, me, amount)],
                          ),
                      ],
                    ),
                    if (rows.isNotEmpty) ...[
                      _listHeading(context, 'Between people'),
                      SharedMoneyTable(
                        key: const ValueKey('who-owes-pairs'),
                        label: 'Who',
                        columns: const ['Amount'],
                        rows: [
                          for (final e in rows)
                            (
                              owesWords(g, e.sender, e.recipient, me),
                              [amount(e.amount)],
                            ),
                        ],
                      ),
                    ],
                    const ListEnd(),
                  ],
                ),
        ),
      );
    },
  );
}
