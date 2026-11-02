import 'dart:convert';

import '../app/overview_data.dart' show addCivilDays;
import '../local/finance_domain.dart';
import 'shared_data.dart';
import 'shared_domain.dart';

/// Display-only views for Balances, People and the pages they open (§2
/// Shared Expenses B, §8). They read the rules in `shared_domain.dart` and add
/// up exact values; nothing here rounds, estimates or works out a share again.

/// What [a] owes [b] in [edges]: negative when [b] owes [a].
BigInt pairNet(Iterable<SharedEdge> edges, String a, String b) => sumMinor(
  edges.map(
    (e) => e.sender == a && e.recipient == b
        ? e.amount
        : e.sender == b && e.recipient == a
        ? -e.amount
        : BigInt.zero,
  ),
);

/// "You owe Nico", "Nico owes you" or "Nico owes Tala".
String owesWords(SharedGroup g, String sender, String recipient, String? me) =>
    sender == me
    ? 'You owe ${g.personName(recipient)}'
    : recipient == me
    ? '${g.personName(sender)} owes you'
    : '${g.personName(sender)} owes ${g.personName(recipient)}';

/// Whether [me] may log a payment from [sender]: their own, or as the owner
/// for someone who isn't registered. Mirrors the server's `report` check.
bool canLogFor(SharedGroup g, String sender, String? me) {
  if (me == null || !g.active(me)) return false;
  return sender == me ||
      (g.data['owner'] == me && g.people[sender]?['kind'] != 'registered');
}

enum PairRowKind { bill, payment }

/// One bill or payment between two people, as the rules attributed it.
class PairRow {
  const PairRow({
    required this.kind,
    required this.id,
    required this.title,
    required this.date,
    required this.change,
    required this.net,
    this.detail = '',
  });
  final PairRowKind kind;
  final String id, title, date, detail;

  /// What this did: above zero it adds to what the first person owes.
  final BigInt change;

  /// What the first person owes the second after this row.
  final BigInt net;
}

/// Every bill and payment between two people, with the running net
/// (DOMAIN_RULES §17–18). [net] is `due(a, b)`, and it's where [rows] end.
class PairBreakdown {
  const PairBreakdown({
    required this.a,
    required this.b,
    required this.rows,
    required this.notCounted,
    required this.net,
    required this.projected,
  });
  final String a, b;
  final List<PairRow> rows;

  /// Payments between them that move nothing: waiting, disputed, cancelled
  /// or reversed.
  final List<SharedPaymentRow> notCounted;
  final BigInt net, projected;
  int get bills => rows.where((r) => r.kind == PairRowKind.bill).length;
  int get payments => rows.where((r) => r.kind == PairRowKind.payment).length;
}

/// Null when the rules can't work it out, which only happens on a partial
/// copy: the screen reads "Not available yet".
PairBreakdown? pairBreakdown(
  SharedGroup g,
  String a,
  String b,
  String? me,
  String today,
) {
  if (!g.complete) return null;
  return guarded(() {
    final edges = g.edges();
    final bills = <String, BigInt>{}, payments = <String, BigInt>{};
    for (final e in edges) {
      final change = pairNet([e], a, b);
      if (change == BigInt.zero) continue;
      final into = g.settlements.containsKey(e.source) ? payments : bills;
      into[e.source] = (into[e.source] ?? BigInt.zero) + change;
    }
    final found = <(PairRowKind, String, String, BigInt, String, String)>[
      for (final e in bills.entries)
        () {
          final r = g.revision(e.key), bill = object(g.bills[e.key]);
          return (
            PairRowKind.bill,
            e.key,
            r['date'] as String,
            e.value,
            r['name'] as String,
            [
              if ((bill['revisions'] as List).length > 1) 'Corrected',
              if ((bill['refunds'] as List).isNotEmpty) 'Refunded',
            ].join(' · '),
          );
        }(),
      for (final e in payments.entries)
        () {
          final p = sharedPaymentRow(g, e.key, me, today);
          return (
            PairRowKind.payment,
            e.key,
            p.date,
            e.value,
            '${p.from} paid ${p.to == 'You' ? 'you' : p.to}',
            appliedLine(g, p),
          );
        }(),
    ];
    // By date. On one day, bills come before the payments made against them.
    found.sort((x, y) {
      final date = x.$3.compareTo(y.$3);
      if (date != 0) return date;
      if (x.$1 != y.$1) return x.$1 == PairRowKind.bill ? -1 : 1;
      return x.$2.compareTo(y.$2);
    });
    var net = BigInt.zero;
    final rows = [
      for (final (kind, id, date, change, title, detail) in found)
        () {
          net += change;
          return PairRow(
            kind: kind,
            id: id,
            title: title,
            date: date,
            change: change,
            net: net,
            detail: detail,
          );
        }(),
    ];
    return PairBreakdown(
      a: a,
      b: b,
      rows: rows,
      notCounted: [
        for (final p in sharedPaymentRows(g, me, today))
          if (p.status != PaymentStatus.confirmed &&
              ({p.sender, p.recipient}.containsAll([a, b])))
            p,
      ],
      net: pairNet(edges, a, b),
      projected: pairNet(g.edges(projected: true), a, b),
    );
  });
}

/// Who owes whom after netting: the user's own pairs first, largest first.
List<SharedEdge> whoOwesRows(SharedGroup g, String? me) {
  if (!g.complete) return const [];
  final pairs = guarded(() => g.reciprocalPairs) ?? const <SharedEdge>[];
  bool mine(SharedEdge e) => e.sender == me || e.recipient == me;
  return [...pairs]..sort((a, b) {
    if (mine(a) != mine(b)) return mine(a) ? -1 : 1;
    if (mine(a) && (a.sender == me) != (b.sender == me)) {
      return a.sender == me ? -1 : 1;
    }
    return b.amount.compareTo(a.amount);
  });
}

/// How many bills and payments stand behind each pair, read in one pass.
Map<(String, String), (int bills, int payments)> pairSources(SharedGroup g) {
  final found = <(String, String), Set<String>>{};
  for (final e in guarded(g.edges) ?? const <SharedEdge>[]) {
    final key = e.sender.compareTo(e.recipient) < 0
        ? (e.sender, e.recipient)
        : (e.recipient, e.sender);
    (found[key] ??= {}).add(e.source);
  }
  return {
    for (final e in found.entries)
      e.key: (
        e.value.where((s) => !g.settlements.containsKey(s)).length,
        e.value.where(g.settlements.containsKey).length,
      ),
  };
}

/// "3 bills · 1 payment".
String sourceWords(int bills, int payments) => detailFacts([
  if (bills > 0) '$bills ${bills == 1 ? 'bill' : 'bills'}',
  if (payments > 0) '$payments ${payments == 1 ? 'payment' : 'payments'}',
]);

/// What the user owes and is owed across [pairs], from `pairsWithMe`. The two
/// together are the user's position.
({BigInt owe, int toPeople, BigInt owed, int fromPeople}) pairTotals(
  Iterable<(String, BigInt)> pairs,
) {
  final out = [
    for (final p in pairs)
      if (p.$2 < BigInt.zero) -p.$2,
  ];
  final into = [
    for (final p in pairs)
      if (p.$2 > BigInt.zero) p.$2,
  ];
  return (
    owe: sumMinor(out),
    toPeople: out.length,
    owed: sumMinor(into),
    fromPeople: into.length,
  );
}

/// Why suggestions show, or don't.
enum SuggestionState { ready, paused, none, unavailable }

/// A proposed payment (DOMAIN_RULES §20). It moves nothing. [owed] is what the
/// sender owes the recipient directly. Anything past that redirects an
/// obligation, which everyone involved has to agree to (§22).
class SuggestionRow {
  const SuggestionRow(this.sender, this.recipient, this.amount, this.owed);
  final String sender, recipient;
  final BigInt amount, owed;
  bool get direct => owed >= amount;
}

(SuggestionState, List<SuggestionRow>) sharedSuggestions(SharedGroup g) {
  if (!g.complete) return (SuggestionState.unavailable, const []);
  if (g.settlements.values.any((s) => s['state'] == 'disputed')) {
    return (SuggestionState.paused, const []);
  }
  final rows = guarded(
    () => [
      for (final e in g.suggestions)
        SuggestionRow(
          e.sender,
          e.recipient,
          e.amount,
          g.due(e.sender, e.recipient),
        ),
    ],
  );
  if (rows == null) return (SuggestionState.unavailable, const []);
  return (rows.isEmpty ? SuggestionState.none : SuggestionState.ready, rows);
}

/// What the group's balances are made of, and what isn't counted.
class BalanceCounts {
  const BalanceCounts({
    required this.bills,
    required this.billCount,
    required this.refunds,
    required this.refundCount,
    required this.confirmed,
    required this.confirmedCount,
    required this.waiting,
    required this.waitingCount,
    required this.disputed,
    required this.disputedCount,
  });
  final BigInt bills, refunds, confirmed, waiting, disputed;
  final int billCount, refundCount, confirmedCount, waitingCount, disputedCount;
}

BalanceCounts balanceCounts(SharedGroup g) {
  final refunds = [
    for (final id in g.bills.keys) ...(g.bills[id]['refunds'] as List),
  ];
  (BigInt, int) inState(String state) {
    final amounts = [
      for (final s in g.settlements.values)
        if (s['state'] == state) sharedMinor(s['amount']),
    ];
    return (sumMinor(amounts), amounts.length);
  }

  final confirmed = inState('confirmed');
  final waiting = inState('pending');
  final disputed = inState('disputed');
  return BalanceCounts(
    bills: sumMinor(
      g.bills.keys.map((id) => sharedMinor(g.revision(id)['total'])),
    ),
    billCount: g.bills.length,
    refunds: sumMinor(refunds.map((f) => sharedMinor(f['total']))),
    refundCount: refunds.length,
    confirmed: confirmed.$1,
    confirmedCount: confirmed.$2,
    waiting: waiting.$1,
    waitingCount: waiting.$2,
    disputed: disputed.$1,
    disputedCount: disputed.$2,
  );
}

/// How one person's position adds up (DOMAIN_RULES §47). [position] equals
/// `positions()[person]`: paid, minus their part, plus payments made, minus
/// payments received.
class PersonBreakdown {
  const PersonBreakdown({
    required this.paid,
    required this.part,
    required this.sent,
    required this.received,
    required this.waitingOut,
    required this.waitingIn,
    required this.position,
  });

  /// Across bills, refunds applied.
  final BigInt paid, part;

  /// Confirmed payments.
  final BigInt sent, received;

  /// Logged and not confirmed, so not counted.
  final BigInt waitingOut, waitingIn;
  final BigInt position;
}

PersonBreakdown? personBreakdown(SharedGroup g, String person) {
  if (!g.complete) return null;
  return guarded(() {
    final totals = peopleTotals(
      g,
      null,
    ).where((p) => p.person == person).firstOrNull;
    BigInt sum(String role, String state) => sumMinor([
      for (final s in g.settlements.values)
        if (s[role] == person && s['state'] == state) sharedMinor(s['amount']),
    ]);
    return PersonBreakdown(
      paid: totals?.paid ?? BigInt.zero,
      part: totals?.part ?? BigInt.zero,
      sent: sum('sender', 'confirmed'),
      received: sum('recipient', 'confirmed'),
      waitingOut: sum('sender', 'pending'),
      waitingIn: sum('recipient', 'pending'),
      position: g.positions()[person]!,
    );
  });
}

/// One bill a person is on, newest first.
class PersonBill {
  const PersonBill(this.id, this.name, this.date, this.paid, this.part);
  final String id, name, date;
  final BigInt paid, part;
}

List<PersonBill> personBills(SharedGroup g, String person) {
  final rows = [
    for (final id in g.bills.keys)
      for (final p in billSplit(g, id, null))
        if (p.person == person)
          PersonBill(
            id,
            g.revision(id)['name'] as String,
            g.revision(id)['date'] as String,
            p.paid,
            p.part,
          ),
  ];
  return rows..sort((a, b) => b.date.compareTo(a.date));
}

/// What someone is in a group.
enum MemberRole {
  owner('Owner'),
  member('Member'),
  notRegistered('Not registered'),
  deleted('Deleted account');

  const MemberRole(this.label);
  final String label;
}

class SharedMember {
  const SharedMember({
    required this.person,
    required this.name,
    required this.role,
    required this.active,
    this.joined,
    this.left,
  });
  final String person, name;
  final MemberRole role;
  final bool active;

  /// Civil dates, from the stored membership history.
  final String? joined, left;

  /// What this person can do, as the server's rules allow it.
  String get can => !active && role != MemberRole.deleted
      ? 'Can’t add anything now. Keeps their earlier records and can still answer payments on them.'
      : switch (role) {
          MemberRole.owner => 'Adds people, sends invitations, archives the group and answers for people who aren’t registered.',
          MemberRole.member =>
            'Adds bills, logs their own payments and answers payments to them.',
          MemberRole.notRegistered =>
            'Can’t sign in. The owner logs and answers payments for them.',
          MemberRole.deleted =>
            'This account is gone. Its bills and balance stay.',
        };
}

SharedMember sharedMember(SharedGroup g, String person) {
  final p = object(g.people[person]);
  final intervals = (p['intervals'] as List?) ?? const [];
  String? stamp(String key, {bool last = false}) {
    final found = [
      for (final i in intervals)
        if (i[key] != null) i[key] as String,
    ];
    return found.isEmpty ? null : civilDayOf(last ? found.last : found.first);
  }

  final active = p['active'] == true;
  return SharedMember(
    person: person,
    name: g.personName(person),
    role: p['kind'] == 'deleted'
        ? MemberRole.deleted
        : p['kind'] != 'registered'
        ? MemberRole.notRegistered
        : g.data['owner'] == person
        ? MemberRole.owner
        : MemberRole.member,
    active: active,
    joined: stamp('joined'),
    left: active ? null : stamp('left', last: true),
  );
}

/// The user, the owner, others by name, then people who left.
List<SharedMember> sharedMembers(SharedGroup g, String? me) {
  int rank(SharedMember m) => m.person == me
      ? 0
      : !m.active
      ? 3
      : m.role == MemberRole.owner
      ? 1
      : 2;
  return [for (final p in g.people.keys) sharedMember(g, p)]..sort((a, b) {
    final order = rank(a).compareTo(rank(b));
    return order != 0
        ? order
        : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
}

/// One change to someone's place in the group.
class MemberEvent {
  const MemberEvent(this.title, this.date, this.reason);
  final String title;
  final String? date, reason;
}

/// A person's membership history in plain words, newest first.
List<MemberEvent> memberHistory(SharedGroup g, String person) {
  final p = object(g.people[person]);
  final events = <MemberEvent>[];
  for (final raw in (p['intervals'] as List?) ?? const []) {
    final i = object(raw);
    final reason = i['reason'] as String?;
    if (i.containsKey('joined')) {
      events.add(
        MemberEvent(
          i['role'] == 'owner' ? 'Started the group' : 'Joined',
          civilDayOf(i['joined'] as String?),
          null,
        ),
      );
    } else if (i.containsKey('left')) {
      final deleted = reason == 'Provider identity deleted';
      events.add(
        MemberEvent(
          deleted
              ? 'Account deleted'
              : i['actor'] == p['user']
              ? 'Left'
              : 'Removed by the owner',
          civilDayOf(i['left'] as String?),
          deleted ? null : reason,
        ),
      );
    } else if (i.containsKey('changedAt')) {
      events.add(
        MemberEvent(
          i['role'] == 'owner' ? 'Became the owner' : 'Stopped being the owner',
          civilDayOf(i['changedAt'] as String?),
          reason,
        ),
      );
    }
  }
  return events.reversed.toList();
}

/// What the server lets the user do to a group now. It mirrors the server's
/// `apply` checks, and the server still decides. Nothing here is offered and
/// then refused: archived groups take only leave, transfer and restore, and
/// the owner can't leave or be removed, so a group can't lose its owner.
class GroupChoices {
  const GroupChoices({
    this.addPeople = false,
    this.remove = false,
    this.transfer = false,
    this.archive = false,
    this.restore = false,
    this.leave = false,
    this.mustHandOver = false,
  });
  final bool addPeople, remove, transfer, archive, restore, leave;

  /// The owner has to make someone else the owner before they can leave.
  final bool mustHandOver;
  bool get any =>
      addPeople || remove || transfer || archive || restore || leave;
}

/// Who can be removed: anyone still in the group except the owner.
List<SharedMember> removableMembers(SharedGroup g) => [
  for (final p in g.people.keys)
    if (g.active(p) && p != g.data['owner']) sharedMember(g, p),
];

/// Who can become the owner: registered members still in the group.
List<SharedMember> ownerCandidates(SharedGroup g) => [
  for (final p in g.people.entries)
    if (p.value['active'] == true &&
        p.value['kind'] == 'registered' &&
        p.key != g.data['owner'])
      sharedMember(g, p.key),
];

GroupChoices groupChoices(SharedGroup g, String? me) {
  if (me == null || !g.active(me)) return const GroupChoices();
  final owner = g.data['owner'] == me;
  final open = !g.archived;
  return GroupChoices(
    addPeople: owner && open && g.people.length < 100,
    remove: owner && open && removableMembers(g).isNotEmpty,
    transfer: owner && ownerCandidates(g).isNotEmpty,
    archive: owner && open,
    restore: owner && g.archived,
    leave: !owner,
    mustHandOver: owner,
  );
}

/// What the user can do about one person.
class MemberChoices {
  const MemberChoices({
    this.remove = false,
    this.makeOwner = false,
    this.claim = false,
  });
  final bool remove, makeOwner;

  /// Invite someone with an account to take this person's place.
  final bool claim;
  bool get any => remove || makeOwner || claim;
}

MemberChoices memberChoices(SharedGroup g, String? me, String person) {
  final all = groupChoices(g, me);
  final p = object(g.people[person]);
  return MemberChoices(
    remove: all.remove && g.active(person) && person != g.data['owner'],
    makeOwner:
        all.transfer &&
        g.active(person) &&
        p['kind'] == 'registered' &&
        person != me,
    claim: all.addPeople && p['kind'] == 'manual' && p['user'] == null,
  );
}

/// An invitation that may still be open. The server keeps invitations to
/// itself, so this can't know one was used: it can only rule out those past
/// their seven days and those this device revoked. Who it's for is known only
/// on the device that sent it.
class OpenInvitation {
  const OpenInvitation(this.id, this.sent, this.expires, this.email);
  final String id, sent, expires;
  final String? email;
}

List<OpenInvitation> openInvitations(
  SharedGroup g,
  Iterable<SharedJson> intents,
  String today,
) {
  final commands = {
    for (final i in intents)
      i['id'] as String: (
        i['state'] as String?,
        object(jsonDecode(i['payload'] as String)),
      ),
  };
  final revoked = {
    for (final (state, command) in commands.values)
      if (command['op'] == 'revoke' && state != 'review')
        object(command['values'])['invitation'],
  };
  final rows = <OpenInvitation>[];
  for (final raw in g.data['activity'] as List) {
    final e = object(raw);
    final sent = civilDayOf(e['at'] as String?);
    if (e['op'] != 'invite' || sent == null || revoked.contains(e['id'])) {
      continue;
    }
    final expires = addCivilDays(sent, 7);
    if (today.compareTo(expires) > 0) continue;
    final command = commands[e['id']]?.$2;
    rows.add(
      OpenInvitation(
        e['id'] as String,
        sent,
        expires,
        command == null ? null : object(command['values'])['email'] as String?,
      ),
    );
  }
  return rows.reversed.toList();
}

enum HistoryKind { bill, payment, people, group }

/// What History can narrow to.
enum HistoryFilter {
  all('All'),
  bills('Bills'),
  payments('Payments'),
  people('People'),
  group('Group');

  const HistoryFilter(this.label);
  final String label;

  bool matches(HistoryRow r) => switch (this) {
    all => true,
    bills => r.kind == HistoryKind.bill,
    payments => r.kind == HistoryKind.payment,
    people => r.kind == HistoryKind.people,
    group => r.kind == HistoryKind.group,
  };
}

/// One thing that happened in a group, in plain words.
class HistoryRow {
  const HistoryRow({
    required this.id,
    required this.kind,
    required this.title,
    this.date,
    this.reason,
    this.amount,
    this.bill,
    this.payment,
  });
  final String id, title;
  final HistoryKind kind;

  /// The civil day it happened, not the date on the bill.
  final String? date;
  final String? reason;
  final BigInt? amount;

  /// What the row opens.
  final String? bill, payment;
}

/// Finds the person a stored time belongs to: the server stamps a membership
/// change and its line in the history with the same time.
String? _personAt(SharedGroup g, String key, String? at, {String? role}) {
  for (final p in g.people.entries) {
    for (final i in (p.value['intervals'] as List?) ?? const []) {
      if (i[key] == at && (role == null || i['role'] == role)) {
        return p.key;
      }
    }
  }
  return null;
}

/// [person]'s name, or "You", or [fallback] when it isn't known.
String _labelOr(SharedGroup g, String? person, String? me, String fallback) =>
    person == null ? fallback : personLabel(g, person, me);

/// A group's history, newest first. A bill or payment gone from a copy of the
/// group still gets its line, in plainer words.
List<HistoryRow> historyRows(SharedGroup g, String? me, String today) {
  final actors = {
    for (final p in g.people.entries)
      if (p.value['user'] != null) p.value['user']: p.key,
  };
  final rows = <HistoryRow>[];
  for (final raw in (g.data['activity'] as List).reversed) {
    final e = object(raw);
    final id = e['id'] as String, op = e['op'] as String?;
    final at = e['at'] as String?;
    final actor = actors[e['actor']];
    final who = _labelOr(g, actor, me, 'Someone');
    String named(String? person) => _labelOr(g, person, me, 'someone');
    String? billId, paymentId;
    BigInt? amount;
    String title;
    var kind = HistoryKind.group;
    switch (op) {
      case 'bill' || 'correct' || 'refund':
        kind = HistoryKind.bill;
        final found = g.bills.entries
            .where(
              (b) =>
                  b.key == id ||
                  (b.value['revisions'] as List).any((r) => r['id'] == id) ||
                  (b.value['refunds'] as List).any((f) => f['id'] == id),
            )
            .firstOrNull;
        billId = found?.key;
        final name = found == null
            ? 'a bill'
            : g.revision(found.key)['name'] as String;
        if (found != null) {
          final revisions = found.value['revisions'] as List;
          amount = sharedMinor(
            op == 'refund'
                ? (found.value['refunds'] as List).firstWhere(
                    (f) => f['id'] == id,
                  )['total']
                : op == 'bill'
                ? revisions.first['total']
                : revisions.firstWhere((r) => r['id'] == id)['total'],
          );
        }
        title = switch (op) {
          'bill' => '$who added $name',
          'correct' => '$who corrected $name',
          _ => '$who logged a refund on $name',
        };
      case 'report' || 'resolve':
        kind = HistoryKind.payment;
        final found = g.settlements.entries
            .where(
              (s) =>
                  s.key == id ||
                  ((s.value['events'] as List?) ?? const []).any(
                    (x) => x['id'] == id,
                  ),
            )
            .firstOrNull;
        paymentId = found?.key;
        final p = found == null
            ? null
            : sharedPaymentRow(g, found.key, me, today);
        amount = p?.amount;
        final state = found == null
            ? null
            : ((found.value['events'] as List?) ?? const [])
                  .where((x) => x['id'] == id)
                  .firstOrNull?['state'];
        final verb = op == 'report'
            ? 'logged'
            : switch (state) {
                'confirmed' => 'confirmed',
                'disputed' => 'disputed',
                'cancelled' => 'cancelled',
                'reversed' => 'undid the confirmation of',
                _ => 'answered',
              };
        title = '$who $verb a payment${p == null ? '' : ': ${p.who}'}';
      case 'manual':
        kind = HistoryKind.people;
        title = '$who added someone who isn’t registered';
      case 'invite':
        kind = HistoryKind.people;
        title = '$who sent an invitation';
      case 'revoke':
        kind = HistoryKind.people;
        title = '$who revoked an invitation';
      case 'accept':
        kind = HistoryKind.people;
        title = '${_labelOr(g, _personAt(g, 'joined', at), me, who)} joined';
      case 'leave':
        kind = HistoryKind.people;
        title = '$who left';
      case 'remove':
        kind = HistoryKind.people;
        title = '$who removed ${named(_personAt(g, 'left', at))}';
      case 'transfer':
        kind = HistoryKind.people;
        final next = _personAt(g, 'changedAt', at, role: 'owner');
        title = '$who made ${named(next)} the owner';
      case 'identity_deleted':
        kind = HistoryKind.people;
        title = 'An account was deleted';
      case 'create':
        title = '$who started the group';
      case 'archive':
        title = '$who archived or restored the group';
      default:
        title = 'The group changed';
    }
    rows.add(
      HistoryRow(
        id: id,
        kind: kind,
        title: title,
        date: civilDayOf(at),
        // The server's note for a deleted account is about its records.
        reason: op == 'identity_deleted'
            ? 'Its bills and balance stay.'
            : e['reason'] as String?,
        amount: amount,
        bill: billId,
        payment: paymentId,
      ),
    );
  }
  return rows;
}

/// What a person's place in the group says about their balance.
String standsWords(
  String person,
  BigInt position,
  String? me,
  String Function(BigInt) amount,
) => position == BigInt.zero
    ? 'All square'
    : '${position > BigInt.zero
          ? 'Owed'
          : person == me
          ? 'Owe'
          : 'Owes'} ${amount(position.abs())}';
