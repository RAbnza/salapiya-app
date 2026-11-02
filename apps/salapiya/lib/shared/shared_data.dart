import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../local/finance_domain.dart';
import '../p0/exact_money.dart';
import 'shared_domain.dart';

/// Display-only views of a group, for Shared Expenses (§2 Shared Expenses A,
/// §8). They read the rules in `shared_domain.dart` and add up exact values;
/// nothing here rounds, estimates or works out a share again.

/// What a form needs from wherever group records live. The real build writes
/// through `SharedRepository`; the demo's answers are fixed.
abstract class SharedWriter {
  String? get actor;
  bool get online;
  Future<String> submit(
    String group,
    String op,
    SharedJson values, {
    int version,
    String? id,
  });
  Future<void> retry(String id);
  Future<SharedJson> reviewInvitation(String code);
  Future<void> draft(String id, String group, SharedJson values);
  Future<SharedJson?> readDraft(String id);
  Future<void> discardDraft(String id);

  /// Notes that the user's own record stays as it is after a bill changed.
  /// Nothing reaches the group. [id] makes a repeat the same review.
  Future<void> keepRecord({
    required String id,
    required String group,
    required String bill,
    required String record,
    required String stamp,
    required String reason,
  });
}

/// Everything Shared Expenses shows, from a real profile or the demo.
class SharedSource {
  const SharedSource({
    required this.today,
    required this.groups,
    required this.loaded,
    required this.connected,
    required this.online,
    required this.complete,
    required this.hidden,
    required this.amount,
    required this.writer,
    required this.profileName,
    this.actor,
    this.intents = const [],
    this.drafts = const [],
    this.reviews = const [],
    this.current = const [],
    this.error,
    this.pendingCount = 0,
    this.needsReview = false,
    this.syncLabel = '',
    this.onReview,
    this.onConnect,
    this.accountName,
    this.demo = false,
  });
  final String today;
  final List<SharedGroup> groups;

  /// The first read has finished, so no groups means there are none.
  final bool loaded;
  final bool connected, online, complete, hidden;
  final String Function(BigInt value) amount;
  final SharedWriter writer;
  final String profileName;
  final String? actor;
  final List<SharedJson> intents, drafts, reviews;

  /// The profile's own current records, to spot links that changed.
  final List<LocalRevision> current;
  final String? error;
  final int pendingCount;
  final bool needsReview;
  final String syncLabel;
  final VoidCallback? onReview, onConnect;

  /// One of the user's own accounts by id, for their own eyes only.
  final String? Function(String id)? accountName;

  /// Saving here doesn't change the sample.
  final bool demo;

  /// The chosen group, or the one that needs the user most.
  SharedGroup? group(String? id) =>
      groups.where((g) => g.id == id).firstOrNull ??
      sharedGroupRows(this).firstOrNull?.group;
}

/// A rule refused to work these figures out, which only happens on a partial
/// copy of a group. Null reads "Not available yet", never a wrong number.
T? guarded<T>(T Function() read) {
  try {
    return read();
  } catch (_) {
    return null;
  }
}

/// Where the user stands in a group.
enum StandingKind {
  owedToYou('You’re owed'),
  youOwe('You owe'),
  square('All square'),
  unknown('Not available yet');

  const StandingKind(this.label);
  final String label;
}

class SharedStanding {
  const SharedStanding(this.kind, this.amount, {this.projected});
  SharedStanding.unknown()
    : kind = StandingKind.unknown,
      amount = BigInt.zero,
      projected = null;
  final StandingKind kind;

  /// Always positive; [kind] says which way it goes.
  final BigInt amount;

  /// Signed position if every waiting payment is confirmed. Null when that
  /// wouldn't change anything.
  final BigInt? projected;
}

/// The user's confirmed position. Waiting payments never change it. A group
/// the user left is a partial copy, so it has no position to show.
SharedStanding sharedStanding(SharedGroup g, String? me) {
  if (me == null || !g.complete) return SharedStanding.unknown();
  final now = guarded(() => g.positions()[me]);
  final next = guarded(() => g.positions(projected: true)[me]);
  if (now == null) return SharedStanding.unknown();
  return SharedStanding(
    now > BigInt.zero
        ? StandingKind.owedToYou
        : now < BigInt.zero
        ? StandingKind.youOwe
        : StandingKind.square,
    now.abs(),
    projected: next == null || next == now ? null : next,
  );
}

/// A signed position in words, for a label that says it's only if confirmed.
String positionWords(BigInt position, String Function(BigInt) amount) =>
    position > BigInt.zero
    ? 'You’d be owed ${amount(position)}'
    : position < BigInt.zero
    ? 'You’d owe ${amount(-position)}'
    : 'You’d be all square';

/// One group in the switcher.
class SharedGroupRow {
  const SharedGroupRow(this.group, this.me, this.standing, this.toConfirm);
  final SharedGroup group;
  final String? me;
  final SharedStanding standing;

  /// Payments waiting for this user, as the shell's count reads them.
  final int toConfirm;
  bool get left => !group.active(me);
  bool get current => !group.archived && !left;
}

/// Current groups by name, then archived ones and groups the user has left.
List<SharedGroupRow> sharedGroupRows(SharedSource source) {
  int waiting(SharedGroup g, String? me) => g.settlements.values
      .where((s) => s['state'] == 'pending' && s['recipient'] == me)
      .length;
  final rows = [
    for (final g in source.groups)
      () {
        final me = g.participant(source.actor ?? '');
        return SharedGroupRow(g, me, sharedStanding(g, me), waiting(g, me));
      }(),
  ];
  return rows..sort((a, b) {
    if (a.current != b.current) return a.current ? -1 : 1;
    if (a.toConfirm > 0 != b.toConfirm > 0) return a.toConfirm > 0 ? -1 : 1;
    return a.group.name.toLowerCase().compareTo(b.group.name.toLowerCase());
  });
}

String _plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : many ?? '${one}s'}';

/// "4 people · 12 bills".
String groupFacts(SharedGroup g) => detailFacts([
  _plural(g.people.length, 'person', 'people'),
  _plural(g.bills.length, 'bill'),
]);
String detailFacts(Iterable<String> facts) => facts.join(' · ');

/// [person]'s name, or "You".
String personLabel(SharedGroup g, String person, String? me) =>
    person == me ? 'You' : g.personName(person);

/// "You paid", "Maria paid", "You and Maria paid" or "3 people paid".
String paidBy(SharedGroup g, Map<String, dynamic> paid, String? me) {
  final payers = [
    for (final e in paid.entries)
      if (sharedMinor(e.value) > BigInt.zero) e.key,
  ]..sort((a, b) => a == me ? -1 : (b == me ? 1 : a.compareTo(b)));
  return switch (payers) {
    [] => 'Nobody paid',
    [final one] => '${personLabel(g, one, me)} paid',
    [final a, final b] =>
      '${personLabel(g, a, me)} and ${personLabel(g, b, me)} paid',
    _ => '${payers.length} people paid',
  };
}

/// One bill as a list shows it.
class SharedBillRow {
  const SharedBillRow({
    required this.id,
    required this.name,
    required this.date,
    required this.paidBy,
    required this.total,
    required this.part,
    this.left,
    this.versions = 1,
    this.refunds = 0,
    this.waiting = false,
  });
  final String id, name, date, paidBy;

  /// After refunds, as `SharedGroup.spending` counts it.
  final BigInt total;

  /// The user's part after refunds. Null when the user isn't in the group.
  final BigInt? part;

  /// Still between the user and others on this bill: positive when the user
  /// owes, negative when they're owed.
  final BigInt? left;
  final int versions, refunds;

  /// Saved here but not in the group's records yet.
  final bool waiting;
  bool get corrected => versions > 1;
}

BigInt _sumOf(Iterable<dynamic> refunds, String key, String? me) =>
    sumMinor(refunds.map((f) => sharedMinor((f[key] as Map?)?[me] ?? '0')));

/// What's still between [me] and others, per bill, with `edges()` read once.
/// Each bill's figure is the sum of `due(me, other, bill: id)` over everyone.
Map<String, BigInt> leftOnBills(SharedGroup g, String me) {
  final left = <String, BigInt>{};
  for (final e in g.edges()) {
    final bill = e.bill;
    if (bill == null) continue;
    if (e.sender == me) {
      left[bill] = (left[bill] ?? BigInt.zero) + e.amount;
    } else if (e.recipient == me) {
      left[bill] = (left[bill] ?? BigInt.zero) - e.amount;
    }
  }
  return left;
}

/// Bills newest first, then the ones still on their way to the group.
List<SharedBillRow> sharedBillRows(
  SharedGroup g,
  String? me, {
  List<SharedJson> intents = const [],
}) {
  final left = me == null ? null : guarded(() => leftOnBills(g, me));
  final rows = <SharedBillRow>[
    for (final id in g.bills.keys)
      () {
        final b = object(g.bills[id]), r = g.revision(id);
        final refunds = b['refunds'] as List;
        final part = me == null
            ? null
            : sharedMinor(r['shares'][me] ?? '0') -
                  _sumOf(refunds, 'credits', me);
        return SharedBillRow(
          id: id,
          name: r['name'] as String,
          date: r['date'] as String,
          paidBy: paidBy(g, object(r['paid']), me),
          total:
              sharedMinor(r['total']) -
              sumMinor(refunds.map((f) => sharedMinor(f['total']))),
          part: part,
          left: left?[id] ?? (left == null ? null : BigInt.zero),
          versions: (b['revisions'] as List).length,
          refunds: refunds.length,
        );
      }(),
  ];
  for (final intent in intents) {
    if (intent['group_id'] != g.id ||
        !const ['pending', 'accepted'].contains(intent['state'])) {
      continue;
    }
    final command = object(jsonDecode(intent['payload'] as String));
    if (command['op'] != 'bill') continue;
    final values = object(command['values']);
    if (g.bills.containsKey(intent['id'])) continue;
    rows.add(
      SharedBillRow(
        id: intent['id'] as String,
        name: values['name'] as String,
        date: values['date'] as String,
        paidBy: paidBy(g, object(values['paid']), me),
        total: sharedMinor(values['total']),
        part: me == null ? null : sharedMinor(values['shares'][me] ?? '0'),
        waiting: true,
      ),
    );
  }
  rows.sort((a, b) {
    final date = b.date.compareTo(a.date);
    return date != 0 ? date : a.name.compareTo(b.name);
  });
  return rows;
}

/// One person on a bill or across a group's bills: what they paid and their
/// part, refunds applied.
class SharedPersonRow {
  const SharedPersonRow({
    required this.person,
    required this.name,
    required this.paid,
    required this.part,
  });
  final String person, name;
  final BigInt paid, part;

  /// Above zero they put in more than their part, as `billPositions` reads.
  BigInt get position => paid - part;
}

List<SharedPersonRow> _peopleRows(
  SharedGroup g,
  String? me,
  Map<String, (BigInt, BigInt)> totals,
) {
  final rows = [
    for (final e in totals.entries)
      SharedPersonRow(
        person: e.key,
        name: personLabel(g, e.key, me),
        paid: e.value.$1,
        part: e.value.$2,
      ),
  ];
  return rows..sort((a, b) {
    if (a.person == me) return -1;
    if (b.person == me) return 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
}

/// Who paid and whose part on one bill, in the order the page lists them.
List<SharedPersonRow> billSplit(SharedGroup g, String id, String? me) {
  final r = g.revision(id), refunds = g.bills[id]['refunds'] as List;
  final ids = {
    ...object(r['paid']).keys,
    ...object(r['shares']).keys,
    for (final f in refunds) ...[
      ...object(f['received']).keys,
      ...object(f['credits']).keys,
    ],
  };
  final totals = <String, (BigInt, BigInt)>{};
  for (final p in ids) {
    final paid =
        sharedMinor(r['paid'][p] ?? '0') - _sumOf(refunds, 'received', p);
    final part =
        sharedMinor(r['shares'][p] ?? '0') - _sumOf(refunds, 'credits', p);
    if (paid != BigInt.zero || part != BigInt.zero) totals[p] = (paid, part);
  }
  return _peopleRows(g, me, totals);
}

/// What each person paid and their part across every bill.
List<SharedPersonRow> peopleTotals(SharedGroup g, String? me) {
  final totals = <String, (BigInt, BigInt)>{};
  for (final id in g.bills.keys) {
    for (final row in billSplit(g, id, me)) {
      final was = totals[row.person] ?? (BigInt.zero, BigInt.zero);
      totals[row.person] = (was.$1 + row.paid, was.$2 + row.part);
    }
  }
  return _peopleRows(g, me, totals);
}

/// Who an equal split gives the extra centavos to (DOMAIN_RULES §49). Empty
/// when it divides evenly or the bill isn't an equal split.
List<String> extraCentavo(SharedJson revision) {
  if (revision['method'] != 'equal') return const [];
  final shares = object(revision['shares']);
  if (shares.isEmpty) return const [];
  final values = shares.values.map(sharedMinor).toList();
  final low = values.reduce((a, b) => a < b ? a : b);
  if (values.every((v) => v == low)) return const [];
  return [
    for (final e in shares.entries)
      if (sharedMinor(e.value) > low) e.key,
  ];
}

/// A month's rows: `2026-10`.
String monthOf(String date) => date.substring(0, 7);

/// The sum of [rows] dated in [month], refunds subtracted, waiting bills left
/// out so it agrees with the group's total.
BigInt monthTotal(Iterable<SharedBillRow> rows, String month) => sumMinor(
  rows.where((r) => !r.waiting && monthOf(r.date) == month).map((r) => r.total),
);

/// The user's part of [rows] dated in [month].
BigInt monthPart(Iterable<SharedBillRow> rows, String month) => sumMinor(
  rows
      .where((r) => !r.waiting && monthOf(r.date) == month)
      .map((r) => r.part ?? BigInt.zero),
);

/// The months up to [today]'s, oldest first, each with what was shared.
List<(String, BigInt)> sharedByMonth(
  Iterable<SharedBillRow> rows,
  String today, {
  int months = 6,
}) {
  final now = DateTime.parse(today);
  return [
    for (var i = months - 1; i >= 0; i--)
      () {
        final d = DateTime.utc(now.year, now.month - i, 1);
        final month = d.toIso8601String().substring(0, 7);
        return ('$month-01', monthTotal(rows, month));
      }(),
  ];
}

/// How a person relates to a payment.
enum PaymentRole { recipient, sender, other }

/// What a payment's state reads as. Sync state never appears here.
enum PaymentStatus {
  toConfirm,
  waiting,
  confirmed,
  disputed,
  cancelled,
  reversed,
}

class SharedPaymentRow {
  const SharedPaymentRow({
    required this.id,
    required this.sender,
    required this.recipient,
    required this.from,
    required this.to,
    required this.date,
    required this.amount,
    required this.status,
    required this.role,
    required this.applied,
    required this.ahead,
    this.manual = false,
    this.waitingDays,
  });
  final String id, sender, recipient, from, to, date;
  final BigInt amount;
  final PaymentStatus status;
  final PaymentRole role;

  /// Bill to amount, as the rules applied it.
  final Map<String, BigInt> applied;

  /// Paid ahead: more than was owed, on no bill.
  final BigInt ahead;

  /// Recorded by the owner; the recipient didn't sign in to confirm it.
  final bool manual;

  /// Days since it was logged, while it waits. Informational (§34).
  final int? waitingDays;
  String get who => '$from → $to';
}

/// A stored time on the Asia/Manila calendar, or null if it can't be read.
String? civilDayOf(String? at) {
  final parsed = at == null ? null : DateTime.tryParse(at);
  return parsed
      ?.toUtc()
      .add(const Duration(hours: 8))
      .toIso8601String()
      .substring(0, 10);
}

PaymentStatus _paymentStatus(String? state, PaymentRole role) =>
    switch (state) {
      'confirmed' => PaymentStatus.confirmed,
      'disputed' => PaymentStatus.disputed,
      'cancelled' => PaymentStatus.cancelled,
      'reversed' => PaymentStatus.reversed,
      _ =>
        role == PaymentRole.recipient
            ? PaymentStatus.toConfirm
            : PaymentStatus.waiting,
    };

SharedPaymentRow sharedPaymentRow(
  SharedGroup g,
  String id,
  String? me,
  String today,
) {
  final s = object(g.settlements[id]);
  final sender = s['sender'] as String, recipient = s['recipient'] as String;
  final role = recipient == me
      ? PaymentRole.recipient
      : sender == me
      ? PaymentRole.sender
      : PaymentRole.other;
  final status = _paymentStatus(s['state'] as String?, role);
  final events = (s['events'] as List?) ?? const [];
  final logged = civilDayOf(
    events.isEmpty ? null : object(events.first)['at'] as String?,
  );
  final open =
      status == PaymentStatus.toConfirm || status == PaymentStatus.waiting;
  return SharedPaymentRow(
    id: id,
    sender: sender,
    recipient: recipient,
    from: personLabel(g, sender, me),
    to: personLabel(g, recipient, me),
    date: s['date'] as String,
    amount: sharedMinor(s['amount']),
    status: status,
    role: role,
    applied: {
      for (final a in object(s['allocations']).entries)
        a.key: sharedMinor(a.value['amount']),
    },
    ahead: sharedMinor(s['advance'] ?? '0'),
    manual: s['manual'] == true,
    waitingDays: !open || logged == null
        ? null
        : DateTime.parse(today).difference(DateTime.parse(logged)).inDays,
  );
}

/// Payments newest first.
List<SharedPaymentRow> sharedPaymentRows(
  SharedGroup g,
  String? me,
  String today,
) {
  final rows = [
    for (final id in g.settlements.keys) sharedPaymentRow(g, id, me, today),
  ];
  return rows..sort((a, b) => b.date.compareTo(a.date));
}

/// What the Payments list can narrow to.
enum PaymentFilter {
  all('All'),
  toConfirm('To confirm'),
  waiting('Waiting'),
  confirmed('Confirmed'),
  disputed('Disputed'),
  closed('Cancelled or reversed');

  const PaymentFilter(this.label);
  final String label;

  bool matches(SharedPaymentRow p) => switch (this) {
    all => true,
    toConfirm => p.status == PaymentStatus.toConfirm,
    waiting => p.status == PaymentStatus.waiting,
    confirmed => p.status == PaymentStatus.confirmed,
    disputed => p.status == PaymentStatus.disputed,
    closed =>
      p.status == PaymentStatus.cancelled || p.status == PaymentStatus.reversed,
  };
}

/// Payments still open: waiting first, then disputed. Newest first in each.
List<SharedPaymentRow> openPayments(Iterable<SharedPaymentRow> rows) => [
  for (final p in rows)
    if (p.status == PaymentStatus.toConfirm) p,
  for (final p in rows)
    if (p.status == PaymentStatus.waiting) p,
  for (final p in rows)
    if (p.status == PaymentStatus.disputed) p,
];

/// What [rows] add up to, and how many there are.
(BigInt, int) paymentTotal(Iterable<SharedPaymentRow> rows) =>
    (sumMinor(rows.map((p) => p.amount)), rows.length);

/// What a payment was put against, in a few words.
String appliedLine(SharedGroup g, SharedPaymentRow p) {
  final bills = p.applied.keys.toList();
  return [
    if (bills.length == 1 && g.bills.containsKey(bills.single))
      g.revision(bills.single)['name'] as String
    else if (bills.isNotEmpty)
      '${bills.length} bills',
    if (p.ahead > BigInt.zero) 'Paid ahead',
  ].join(' + ');
}

/// §29: what the sender owes the recipient now, and if everything waiting is
/// confirmed. Null when the group can't work it out.
(BigInt now, BigInt next)? paymentProjection(
  SharedGroup g,
  SharedPaymentRow p,
) {
  if (!g.complete) return null;
  return guarded(() {
    BigInt pair(Iterable<SharedEdge> edges) => sumMinor(
      edges.map(
        (e) => e.sender == p.sender && e.recipient == p.recipient
            ? e.amount
            : e.sender == p.recipient && e.recipient == p.sender
            ? -e.amount
            : BigInt.zero,
      ),
    );
    return (pair(g.edges()), pair(g.edges(projected: true)));
  });
}

/// What [sender] owes [recipient], or nothing when it can't be worked out.
BigInt owedBetween(SharedGroup g, String sender, String recipient) =>
    guarded(() => g.due(sender, recipient)) ?? BigInt.zero;

/// The payments applied to [bill], with what each put on it.
List<(SharedPaymentRow, BigInt)> billPayments(
  SharedGroup g,
  String bill,
  String? me,
  String today,
) => [
  for (final row in sharedPaymentRows(g, me, today))
    if (row.applied.containsKey(bill)) (row, row.applied[bill]!),
];

/// What the rules let the user do to a payment now. Mirrors the server's
/// `resolve` check; it still decides. Nothing here is offered and refused.
class PaymentChoices {
  const PaymentChoices({
    this.confirm = false,
    this.dispute = false,
    this.cancel = false,
    this.undo = false,
    this.manual = false,
  });
  final bool confirm, dispute, cancel, undo;

  /// The recipient isn't registered, so this needs their limitation agreed.
  final bool manual;
  bool get any => confirm || dispute || cancel || undo;
}

PaymentChoices paymentChoices(SharedGroup g, String id, String? me) {
  final s = object(g.settlements[id]);
  final state = s['state'], recipient = s['recipient'];
  final registered = g.people[recipient]?['kind'] == 'registered';
  final owner = me != null && g.data['owner'] == me && g.active(me);
  final answers = me != null && (recipient == me || (owner && !registered));
  return PaymentChoices(
    confirm: answers && state == 'pending',
    dispute: answers && state == 'pending',
    undo: answers && state == 'confirmed',
    cancel:
        me != null &&
        s['sender'] == me &&
        (state == 'pending' || state == 'disputed'),
    manual: !registered,
  );
}

/// Whether [me] may correct or refund [bill]: its creator, in a group that
/// can still change. Being online is a separate check, because it can change.
bool canChangeBill(SharedGroup g, String bill, String? me) =>
    me != null &&
    g.active(me) &&
    !g.archived &&
    g.bills[bill]?['creator'] == me;

/// People the user owes or who owe the user, largest first within each.
List<(String person, BigInt signed)> pairsWithMe(SharedGroup g, String? me) {
  if (me == null || !g.complete) return const [];
  final pairs = guarded(() => g.reciprocalPairs) ?? const <SharedEdge>[];
  final rows = [
    for (final p in pairs)
      if (p.sender == me)
        (p.recipient, -p.amount)
      else if (p.recipient == me)
        (p.sender, p.amount),
  ];
  return rows..sort((a, b) => a.$2.compareTo(b.$2));
}

/// What a saved draft is about, in the user's own words.
String draftTitle(SharedJson payload, SharedGroup? g) {
  final fields = object(payload['fields'] ?? const <String, dynamic>{});
  String named(String? bill, String fallback) {
    final revisions = bill == null
        ? null
        : g?.bills[bill]?['revisions'] as List?;
    return revisions == null ? fallback : revisions.last['name'] as String;
  }

  if (payload['op'] == 'report') {
    final to = fields['recipient'] as String? ?? '';
    final name = to.isEmpty ? null : g?.people[to]?['name'] as String?;
    return name == null ? 'Payment between members' : 'Payment to $name';
  }
  final typed = (fields['name'] as String? ?? '').trim();
  final source = payload['source'] as String?;
  if (payload['refund'] == true) {
    return 'Refund on ${named(source, 'a bill')}';
  }
  if (source != null) {
    return 'Correction to ${typed.isEmpty ? named(source, 'a bill') : typed}';
  }
  return typed.isEmpty ? 'Untitled shared expense' : typed;
}

/// A group command in the user's words.
String intentTitle(SharedJson command, SharedGroup? g) {
  final values = object(command['values'] ?? const <String, dynamic>{});
  final bill = values['bill'] as String?;
  final name = values['name'] as String?;
  final recipient = values['recipient'] as String?;
  return switch (command['op']) {
    'bill' => name ?? 'Shared expense',
    'correct' => 'Correction to ${name ?? 'a bill'}',
    'refund' =>
      'Refund on ${g != null && bill != null && g.bills.containsKey(bill) ? g.revision(bill)['name'] : 'a bill'}',
    'report' =>
      recipient == null
          ? 'Payment between members'
          : 'Payment to ${g?.personName(recipient) ?? 'a member'}',
    'resolve' => 'Your answer on a payment',
    'create' => 'New group: ${name ?? 'unnamed'}',
    'manual' => 'Add ${name ?? 'a person'}',
    'invite' => 'An invitation',
    'revoke' => 'Revoke an invitation',
    'accept' => 'Join a group',
    'leave' => 'Leave the group',
    'remove' => 'Remove a person',
    'transfer' => 'Change the owner',
    'archive' => 'Archive the group',
    _ => 'A group change',
  };
}

/// What a saved command is doing. Business state is separate: a payment
/// that reached the group can still be waiting for someone to confirm it.
String intentState(SharedJson intent) => switch (intent['state']) {
  'pending' => 'Waiting to sync',
  'accepted' => 'Reached the group · finishing the download',
  'restored' => 'Restored from a backup · check it first',
  _ => sharedReason(intent['reason'] as String?),
};

enum SharedTaskKind { refused, waiting, restored, draft, changed }

/// Something on Bills or Payments that needs the user.
class SharedTask {
  const SharedTask(this.kind, this.id, this.title, this.detail);
  final SharedTaskKind kind;

  /// The intent, draft or bill it's about.
  final String id;
  final String title, detail;
}

/// Which tab's work to list. People and group changes used to show on Bills.
enum SharedTaskScope { bills, payments, people, group }

SharedTaskScope _scopeOf(Object? op) => switch (op) {
  'report' || 'resolve' => SharedTaskScope.payments,
  'manual' || 'invite' || 'revoke' || 'remove' => SharedTaskScope.people,
  'leave' || 'transfer' || 'archive' => SharedTaskScope.group,
  _ => SharedTaskScope.bills,
};

/// What needs the user on one tab, most pressing first: refused commands,
/// restored ones, linked records that changed, drafts, then waiting work.
List<SharedTask> sharedTasks(
  SharedSource source,
  SharedGroup g, {
  required SharedTaskScope scope,
}) {
  final tasks = <SharedTask>[];
  final known = source.groups.map((x) => x.id).toSet();
  final me = g.participant(source.actor ?? '');
  for (final intent in source.intents) {
    if (intent['group_id'] != g.id) continue;
    final state = intent['state'];
    if (state == 'reconciled') continue;
    final command = object(jsonDecode(intent['payload'] as String));
    if (_scopeOf(command['op']) != scope) continue;
    tasks.add(
      SharedTask(
        switch (state) {
          'review' => SharedTaskKind.refused,
          'restored' => SharedTaskKind.restored,
          _ => SharedTaskKind.waiting,
        },
        intent['id'] as String,
        intentTitle(command, g),
        intentState(intent),
      ),
    );
  }
  if (scope == SharedTaskScope.bills && me != null) {
    for (final r in source.current) {
      if (r.values['sharedGroup'] != g.id || r.values['sharedMode'] != 'bill') {
        continue;
      }
      final key = r.values['sharedKey'];
      if (guarded(
            () => privateBillNeedsSharedReview(
              g,
              me,
              r,
              source.current,
              source.reviews,
            ),
          ) ==
          true) {
        tasks.add(
          SharedTask(
            SharedTaskKind.changed,
            key ?? r.id,
            key != null && g.bills.containsKey(key)
                ? g.revision(key)['name'] as String
                : r.title,
            'This bill changed, so your own record needs a look',
          ),
        );
      }
    }
  }
  for (final d in source.drafts) {
    final payload = object(jsonDecode(d['payload'] as String));
    final group = d['group_id'] as String?;
    if (group != g.id && known.contains(group)) continue;
    final tab = payload['op'] == 'report'
        ? SharedTaskScope.payments
        : SharedTaskScope.bills;
    if (tab != scope) continue;
    tasks.add(
      SharedTask(
        SharedTaskKind.draft,
        d['id'] as String,
        draftTitle(payload, g),
        group == g.id ? 'Draft · not sent' : 'Draft · its group isn’t here yet',
      ),
    );
  }
  const order = [
    SharedTaskKind.refused,
    SharedTaskKind.restored,
    SharedTaskKind.changed,
    SharedTaskKind.draft,
    SharedTaskKind.waiting,
  ];
  return tasks
    ..sort((a, b) => order.indexOf(a.kind).compareTo(order.indexOf(b.kind)));
}

/// The server's refusals, as stored, in the user's words. Stored records and
/// the server's own text stay as they are; only the screen changes them.
const sharedReasons = {
  'Group changed; refresh and review':
      'The group changed while you were working. Check it and try again.',
  'Group unavailable': 'This group isn’t available to you.',
  'Group is archived': 'This group is archived, so it can’t change.',
  'Current membership required': 'You’re no longer in this group.',
  'Creator and current revision required':
      'This bill changed, or only the person who added it can change it.',
  'Correction contradicts retained refund caps':
      'A refund on this bill is more than this change leaves.',
  'Refund precedes bill': 'A refund can’t be dated before its bill.',
  'Refund exceeds remaining source cap':
      'That’s more than what’s left to refund for someone on this bill.',
  'Former participant cannot enter a new bill':
      'Someone on this bill has left the group.',
  'Bill limit 1000': 'This group has reached its limit for these records.',
  'Settlement limit 1000':
      'This group has reached its limit for these records.',
  'Refund limit 1000': 'This group has reached its limit for these records.',
  'Revision limit 100': 'This group has reached its limit for these records.',
  'Sender authority required': 'You can only log your own payments here.',
  'Recipient authority required':
      'Only the person who received it can do this.',
  'Sender may cancel an open report':
      'Only the person who sent it can cancel, while it’s still open.',
  'Invalid settlement transition':
      'This payment has already changed. Check it first.',
  'Selected source changed or exceeds capacity':
      'A bill you chose changed, or this is more than what’s left on it.',
  'Full payment must equal current pairwise net':
      'What’s owed changed. Check the amount.',
  'Acknowledge advance or over-net payment explicitly':
      'This is more than what’s owed. Confirm that’s right.',
  'Payment source changed; cancel and review': 'A bill in this payment changed. The sender needs to cancel it and log it again.',
  'Relationship changed; review advance':
      'What’s owed between you changed. Check it and try again.',
  'Manual receipt is unverified; explicit acknowledgement required':
      'Confirm that this person didn’t sign in to confirm it.',
  'Invitation unavailable, expired, changed or wrong verified recipient': 'This invitation isn’t available. It may have expired or been meant for another account.',
  'Invitation unavailable, changed, expired or wrong verified recipient': 'This invitation isn’t available. It may have expired or been meant for another account.',
  'Invitation unavailable': 'This invitation isn’t available. It may have expired or been meant for another account.',
  'Already an active member': 'You’re already in this group.',
  'Owner required': 'Only the group’s owner can do this.',
  'Owner required; participant limit 100':
      'Only the owner can add people, and a group holds up to 100.',
  'Participant limit 100': 'This group is full. It holds up to 100 people.',
  'Participant already exists': 'This person is already in the group.',
  'Invalid invitation': 'Check the email address and try again.',
  'Nominate an unclaimed manual participant':
      'This person already has an account here.',
  'Identity claim requires review':
      'This invitation is for someone else in the group.',
  'Transfer to an active registered member':
      'The new owner must be a registered member who’s still in the group.',
  'Transfer ownership before exit; current authority required':
      'The owner can’t leave or be removed. Make someone else the owner first.',
  'Outside retained entitlement':
      'This payment is on records you no longer have.',
  'Settlement unavailable': 'This payment isn’t here any more.',
  'Private source or group evidence changed':
      'Your record or this bill changed. Check it and try again.',
  'Group history exceeds the reviewed 10 MiB bound; export and review capacity':
      'This group has reached its limit for these records.',
};

const sharedReasonFallback =
    'The group didn’t accept this. Check it and try again.';

/// A refusal as the screen shows it. Messages from our own rules are already
/// plain, so they pass through; anything else unknown gets the fallback.
String sharedReason(String? reason) {
  if (reason == null || reason.isEmpty) return sharedReasonFallback;
  return sharedReasons[reason] ??
      (sharedReasons.containsValue(reason) || reason.endsWith('.')
          ? reason
          : sharedReasonFallback);
}

/// Exact PHP from what was typed: null while it isn't a valid amount yet.
BigInt? typedAmount(String? text) {
  final value = (text ?? '').trim();
  if (value.isEmpty) return null;
  try {
    return parsePhp(value);
  } on FormatException {
    return null;
  }
}

/// A typed amount for a command: blank counts as nothing, as `0.00` did.
BigInt typedOrZero(String? text) =>
    (text ?? '').trim().isEmpty ? BigInt.zero : parsePhp(text!.trim());
