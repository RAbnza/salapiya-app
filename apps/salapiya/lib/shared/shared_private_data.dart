import '../local/finance_domain.dart';
import 'shared_data.dart';
import 'shared_domain.dart';

/// My Records (§2 Shared Expenses B, §8). Display-only views of the user's own
/// records against a group. They read the profile's own store and the user's
/// own reviews, so nothing here can reach another member, and nothing here
/// reaches the group: group documents hold no private fields.

/// The user's own records that point at one group source.
LocalRevision? _linked(
  Iterable<LocalRevision> current,
  String group,
  String key,
  String mode,
) => current
    .where(
      (r) =>
          r.values['sharedGroup'] == group &&
          r.values['sharedKey'] == key &&
          r.values['sharedMode'] == mode,
    )
    .firstOrNull;

/// What the user's records hold for one payment.
class PaymentLinks {
  const PaymentLinks(this.payment, this.clearing, this.restored);
  final LocalRevision? payment, clearing;

  /// It was counted in the group balance, then taken out again.
  final bool restored;
  bool get added => payment != null;

  /// Add to my Money, or Review my record: anyone in the payment, unless it
  /// was cancelled.
  bool canAdd(PaymentStatus status) => status != PaymentStatus.cancelled;
  bool canCount(PaymentStatus status) =>
      status == PaymentStatus.confirmed && added && clearing == null;
  bool canTakeOut(PaymentStatus status) =>
      status == PaymentStatus.reversed && clearing != null && !restored;
}

PaymentLinks paymentLinks(
  Iterable<LocalRevision> current,
  String group,
  String payment,
) {
  final clearing = _linked(current, group, payment, 'clear');
  return PaymentLinks(
    _linked(current, group, payment, 'payment'),
    clearing,
    clearing != null && current.any((r) => r.source == clearing.id),
  );
}

enum PrivateKind {
  bill('Bill'),
  payment('Payment'),
  refund('Refund');

  const PrivateKind(this.label);
  final String label;
}

/// Where one item stands in the user's own records. Sync state never appears
/// here, and neither does anything about another member's records.
enum PrivateState {
  notAdded('Not in my Money'),
  added('In my Money'),
  needsLook('Needs a look'),
  kept('Kept as it is'),
  toCount('To count'),
  counted('Counted'),
  toTakeOut('To take out'),
  takenOut('Taken out');

  const PrivateState(this.label);
  final String label;
  bool get needsYou =>
      this == needsLook || this == toCount || this == toTakeOut;
  bool get inMoney => this != notAdded;
}

/// One bill, payment or refund the user is part of, or one of their records
/// whose source is gone.
class PrivateRow {
  const PrivateRow({
    required this.kind,
    required this.id,
    required this.title,
    required this.date,
    required this.state,
    required this.group,
    this.record,
    this.bill,
    this.gone = false,
    this.paid,
    this.part,
  });
  final PrivateKind kind;
  final String id, title, date;
  final PrivateState state;

  /// What the group says: the bill's total share for the user, the payment,
  /// or the refund's amount. Null when the source is gone.
  final BigInt? group;

  /// What the group says the user paid and their part, on a bill or refund.
  final BigInt? paid, part;
  final LocalRevision? record;

  /// The bill a refund belongs to.
  final String? bill;

  /// The group's copy no longer has this source.
  final bool gone;

  /// What the user's own record holds, from its stored funding amount.
  BigInt? get mine {
    final r = record;
    if (r == null) return null;
    final text =
        r.values[kind == PrivateKind.bill ? 'shareAmount' : 'fundingAmount'];
    return text == null ? null : typedAmount(text);
  }
}

BigInt _money(dynamic map, String? key) =>
    sharedMinor((map as Map?)?[key] ?? '0');

/// Whether a review keeps [record] as it is for the bill as it stands.
bool _kept(
  SharedGroup g,
  String bill,
  LocalRevision record,
  Iterable<SharedJson> reviews,
) => reviews.any(
  (r) =>
      r['historicalOnly'] != true &&
      r['group_id'] == g.id &&
      r['bill_id'] == bill &&
      r['private_revision'] == record.id &&
      r['source_stamp'] == sharedSourceStamp(object(g.bills[bill])),
);

/// Everything the user is part of in [g], against their own records. Things
/// that need the user come first, then the newest. A group the user left
/// lists only what's already linked, because nothing new can be added there.
List<PrivateRow> privateRows(
  SharedGroup g,
  String? me,
  Iterable<LocalRevision> current,
  Iterable<SharedJson> reviews,
  String today,
) {
  if (me == null) return const [];
  final active = g.active(me);
  final seen = <String>{};
  final rows = <PrivateRow>[];
  for (final id in g.bills.keys) {
    final r = g.revision(id);
    final bill = object(g.bills[id]);
    final record = _linked(current, g.id, id, 'bill');
    final paid = _money(r['paid'], me), part = _money(r['shares'], me);
    if (record != null) seen.add(record.id);
    if (record != null || (active && (paid + part) > BigInt.zero)) {
      rows.add(
        PrivateRow(
          kind: PrivateKind.bill,
          id: id,
          title: r['name'] as String,
          date: r['date'] as String,
          state: record == null
              ? PrivateState.notAdded
              : guarded(
                      () => privateBillNeedsSharedReview(
                        g,
                        me,
                        record,
                        current,
                        reviews,
                      ),
                    ) !=
                    false
              ? PrivateState.needsLook
              : _kept(g, id, record, reviews)
              ? PrivateState.kept
              : PrivateState.added,
          group: part,
          paid: paid,
          part: part,
          record: record,
        ),
      );
    }
    for (final raw in bill['refunds'] as List) {
      final f = object(raw);
      final back = _money(f['received'], me);
      final credit = _money(f['credits'], me);
      final refund = _linked(current, g.id, f['id'] as String, 'refund');
      if (refund != null) seen.add(refund.id);
      if (refund != null || (active && (back + credit) > BigInt.zero)) {
        rows.add(
          PrivateRow(
            kind: PrivateKind.refund,
            id: f['id'] as String,
            title: 'Refund on ${r['name']}',
            date: f['date'] as String,
            state: refund == null ? PrivateState.notAdded : PrivateState.added,
            group: back,
            paid: back,
            part: credit,
            record: refund,
            bill: id,
          ),
        );
      }
    }
  }
  for (final id in g.settlements.keys) {
    final p = sharedPaymentRow(g, id, me, today);
    if (p.role == PaymentRole.other) continue;
    final links = paymentLinks(current, g.id, id);
    for (final r in [links.payment, links.clearing]) {
      if (r != null) seen.add(r.id);
    }
    if (links.payment == null && (!active || !links.canAdd(p.status))) {
      continue;
    }
    rows.add(
      PrivateRow(
        kind: PrivateKind.payment,
        id: id,
        title: p.who,
        date: p.date,
        state: !links.added
            ? PrivateState.notAdded
            : links.canCount(p.status)
            ? PrivateState.toCount
            : links.canTakeOut(p.status)
            ? PrivateState.toTakeOut
            : links.restored
            ? PrivateState.takenOut
            : links.clearing != null
            ? PrivateState.counted
            : PrivateState.added,
        group: p.amount,
        record: links.payment,
      ),
    );
  }
  // The user's records keep their place even if the group's copy lost them.
  for (final r in current) {
    final mode = r.values['sharedMode'];
    if (r.values['sharedGroup'] != g.id ||
        seen.contains(r.id) ||
        !const ['bill', 'payment', 'refund'].contains(mode)) {
      continue;
    }
    rows.add(
      PrivateRow(
        kind: switch (mode) {
          'bill' => PrivateKind.bill,
          'refund' => PrivateKind.refund,
          _ => PrivateKind.payment,
        },
        id: r.values['sharedKey'] ?? r.id,
        title: sharedRecordTitle(r.title),
        date: r.date,
        state: mode == 'bill' ? PrivateState.needsLook : PrivateState.added,
        group: null,
        record: r,
        gone: true,
      ),
    );
  }
  rows.sort((a, b) {
    if (a.state.needsYou != b.state.needsYou) return a.state.needsYou ? -1 : 1;
    final date = b.date.compareTo(a.date);
    return date != 0 ? date : a.title.compareTo(b.title);
  });
  return rows;
}

/// What [rows] hold, for the tiles.
({int needs, int added, int notAdded}) privateCounts(
  Iterable<PrivateRow> rows,
) => (
  needs: rows.where((r) => r.state.needsYou).length,
  added: rows.where((r) => r.state.inMoney).length,
  notAdded: rows.where((r) => !r.state.inMoney).length,
);

/// What the user's own records say about a group: owed to them above zero.
/// It's a plain sum of their records, as Reports' group lines are, and it
/// isn't compared with the group's figure: the two differ for as long as
/// something isn't in Money or isn't counted, and no rule defines a gap.
BigInt myGroupBalance(Iterable<LocalRevision> current, String group) =>
    sumMinor(
      current
          .where((r) => r.values['sharedGroup'] == group)
          .expand((r) => r.postings)
          .where(
            (p) =>
                p.ledger == 'shared_receivable' || p.ledger == 'shared_payable',
          )
          .map((p) => p.amount),
    );

/// The reviews on one group, the user's own only, newest first.
List<SharedJson> reviewsFor(Iterable<SharedJson> reviews, String group) => [
  for (final r in reviews)
    if (r['group_id'] == group) r,
];

/// A stored title in plain words. Stored records stay as they are.
String sharedRecordTitle(String title) {
  const words = {
    'Shared clear · ': 'Counted in group balance · ',
    'Shared unclear · ': 'Taken out of group balance · ',
  };
  for (final e in words.entries) {
    if (title.startsWith(e.key)) {
      return '${e.value}${title.substring(e.key.length)}';
    }
  }
  return title;
}

/// What a private form works from: the group's source and the user's records
/// that touch it. Throws a rule's refusal when the form can't open.
class PrivateContext {
  PrivateContext({
    required this.group,
    required this.key,
    required this.mode,
    required this.snapshot,
    required this.source,
    required this.me,
    required this.linked,
    required this.payment,
    required this.clearing,
    required this.refundBill,
    required this.refundCoverage,
    required this.outgoing,
    required this.paid,
    required this.share,
    this.savedPurchase,
  });
  final SharedGroup group;
  final String key, mode, me;
  final LocalSnapshot snapshot;
  final SharedJson source;
  final LocalRevision? linked, payment, clearing;
  final MapEntry<String, dynamic>? refundBill;
  final bool refundCoverage, outgoing;

  /// What the group says the user paid and their part.
  final BigInt paid, share;

  /// The purchase this bill was shared from, kept when it was sent.
  final String? savedPurchase;

  static PrivateContext open(
    SharedGroup g,
    String? actor,
    String key,
    String mode,
    LocalSnapshot snapshot, {
    Map<String, dynamic>? purchaseDraft,
  }) {
    final me = g.participant(actor ?? '');
    if (me == null) reject('You’re not in this group on this profile.');
    final current = snapshot.current;
    final linked = _linked(current, g.id, key, mode);
    final saved = mode == 'bill'
        ? ((purchaseDraft?['values'] as Map?)?['privateSource'] as String?)
        : null;
    if (linked == null &&
        purchaseDraft != null &&
        !current.any(
          (r) =>
              r.id == saved &&
              r.kind == 'expense' &&
              !r.values.containsKey('sharedGroup'),
        )) {
      reject(
        'The purchase you saved changed. Check it in Money first. Your spending stays as it is.',
      );
    }
    final source = mode == 'bill'
        ? g.revision(key)
        : mode == 'refund'
        ? object(
            g.bills.values
                .expand((b) => b['refunds'] as List)
                .firstWhere((f) => f['id'] == key),
          )
        : object(g.settlements[key]);
    final refundBill = mode == 'refund'
        ? g.bills.entries.firstWhere(
            (b) => (b.value['refunds'] as List).any((f) => f['id'] == key),
          )
        : null;
    final outgoing = const ['payment', 'clear', 'unclear'].contains(mode)
        ? source['sender'] == me
        : false;
    return PrivateContext(
      group: g,
      key: key,
      mode: mode,
      me: me,
      snapshot: snapshot,
      source: source,
      linked: linked,
      payment: _linked(current, g.id, key, 'payment'),
      clearing: _linked(current, g.id, key, 'clear'),
      refundBill: refundBill,
      refundCoverage:
          refundBill != null &&
          current.any(
            (r) =>
                r.values['sharedMode'] == 'bill' &&
                r.values['sharedGroup'] == g.id &&
                r.values['sharedKey'] == refundBill.key &&
                r.values['sharedRevision'] == g.revision(refundBill.key)['id'],
          ),
      outgoing: outgoing,
      paid: mode == 'bill'
          ? sharedMinor(source['paid'][me] ?? '0')
          : mode == 'refund'
          ? sharedMinor(source['received'][me] ?? '0')
          : sharedMinor(source['amount']),
      share: mode == 'bill'
          ? sharedMinor(source['shares'][me] ?? '0')
          : mode == 'refund'
          ? sharedMinor(source['credits'][me] ?? '0')
          : BigInt.zero,
      savedPurchase: saved,
    );
  }

  bool get isPayment => mode == 'payment';
  bool get isClear => mode == 'clear' || mode == 'unclear';

  /// The amount a clear or unclear must repeat: the user's own record's, not
  /// the group's. The rule refuses anything else.
  String get fixedAmount =>
      (mode == 'clear' ? payment : clearing)?.values['fundingAmount'] ??
      phpDecimal(paid);

  /// What the form starts from. Every key is here, shown or not.
  Map<String, String> startingValues() {
    final current = snapshot.current;
    final existing = mode == 'bill' && linked == null
        ? savedPurchase ?? ''
        : '';
    final categories = snapshot.categories.where((c) => c.kind == 'expense');
    final category = linked?.values['category'] ?? 'category-food';
    return {
      'account': linked?.values['account'] ?? '',
      'category': categories.any((c) => c.id == category)
          ? category
          : categories.firstOrNull?.id ?? category,
      if (mode == 'bill' && linked == null) 'existing': existing,
      if (mode == 'payment' && linked == null) 'existingPayment': '',
      if (mode == 'refund' && linked == null) 'existingCardRefund': '',
      'fundingAmount': isClear
          ? fixedAmount
          : linked?.values['fundingAmount'] ?? phpDecimal(paid),
      'shareAmount': phpDecimal(share),
      'date': linked?.date ?? source['date'] as String,
      if (linked != null) 'acknowledgeFunding': 'false',
      'acknowledge': 'false',
      'reason': '',
    }..addAll(
      existing.isEmpty
          ? const {}
          : lockedTo(current.firstWhere((r) => r.id == existing)),
    );
  }

  /// The values a chosen record fixes, because the rules insist on them.
  Map<String, String> lockedTo(LocalRevision r) => {
    'fundingAmount': r.values.containsKey('sharedGroup')
        ? r.values['fundingAmount'] ?? ''
        : phpDecimal(r.amount),
    'date': r.date,
    'account': r.values['account'] ?? '',
  };

  /// Saved purchases this bill can take over: only what the rules accept.
  List<LocalRevision> get purchases => [
    for (final r in snapshot.current)
      if (r.kind == 'expense' &&
          !r.values.containsKey('sharedGroup') &&
          r.values['split'] != 'true' &&
          (sharedSourceUsesCard(r) || _openAccount(r)))
        r,
  ];

  bool _openAccount(LocalRevision r) => snapshot.accounts.any(
    (a) =>
        a.id == r.values['account'] &&
        !a.archived &&
        r.date.compareTo(a.cutoff) > 0,
  );

  /// Payments already in Money, from one that was cancelled or reversed.
  List<LocalRevision> get reusablePayments => [
    for (final r in snapshot.current)
      if (r.values['sharedMode'] == 'payment' &&
          r.values['sharedGroup'] == group.id &&
          r.values['sharedKey'] != key &&
          r.values['direction'] == (outgoing ? 'out' : 'in') &&
          const [
            'cancelled',
            'reversed',
          ].contains(group.settlements[r.values['sharedKey']]?['state']))
        r,
  ];

  /// Card refunds in Money this refund can take over.
  List<LocalRevision> get cardRefunds => [
    for (final r in snapshot.current)
      if (financeType(r) == 'cardRefund' &&
          !r.values.containsKey('sharedGroup'))
        r,
  ];

  /// The command's values, as they've always been.
  Map<String, String> command(Map<String, String> v) {
    final chosen =
        v['existing'] ?? v['existingPayment'] ?? v['existingCardRefund'];
    final old =
        linked ?? snapshot.current.where((r) => r.id == chosen).firstOrNull;
    // Cash forms retain unused card selector values. Only the validated
    // immutable transaction type establishes actual card funding.
    final cardFunded = sharedSourceUsesCard(old);
    return {
      'name': 'Shared $mode · ${mode == 'bill' ? source['name'] : group.name}',
      'date': v['date']!,
      'sharedMode': mode,
      'sharedAccounting': '2',
      'sharedGroup': group.id,
      'sharedKey': key,
      'sharedRevision': source['id'] as String,
      'fundingAmount': v['fundingAmount']!,
      'shareAmount': v['shareAmount']!,
      'account': v['account']!,
      'category': v['category']!,
      'reason': v['reason']!,
      'funding': cardFunded ? 'card' : 'cash',
      if (cardFunded) 'card': old!.values['card']!,
      'acknowledge': v['acknowledge']!,
      'acknowledgeFunding': v['acknowledgeFunding'] ?? 'false',
      if (old != null) ...{'source': old.id, 'sourceVersion': '${old.number}'},
      if (const ['payment', 'clear', 'unclear'].contains(mode))
        'direction': outgoing ? 'out' : 'in',
      if (mode == 'clear') 'paymentSource': payment?.id ?? '',
      if (mode == 'unclear') 'paymentSource': clearing?.id ?? '',
      if (refundBill != null) ...{
        'billSource': refundBill!.key,
        'billRevision': group.revision(refundBill!.key)['id'] as String,
        'coverage': refundCoverage ? 'adopted' : 'clearing',
      },
    };
  }
}
