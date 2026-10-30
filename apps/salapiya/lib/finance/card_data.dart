import '../app/overview_data.dart';
import '../local/finance_domain.dart';

/// Display-only derivations for Cards (DESIGN_SYSTEM §8, Chat 9). They group,
/// filter and add up exact values the domain already returns, and no money
/// rule lives here. Dates are civil `YYYY-MM-DD` strings.

/// The latest date the rules support, for "everything still open".
const _farAhead = '2199-12-31';

BigInt _max(BigInt a, BigInt b) => a > b ? a : b;
BigInt _min(BigInt a, BigInt b) => a < b ? a : b;

/// The current card with this action id.
LocalRevision? cardRecord(LocalSnapshot s, String? actionId) => s.current
    .where((r) => financeType(r) == 'creditCard' && r.actionId == actionId)
    .firstOrNull;

/// A card's name for lists.
String cardName(LocalSnapshot s, String? actionId) =>
    cardRecord(s, actionId)?.title ?? 'Card';

/// One statement: what the issuer said, and what's matched to it so far.
class StatementRow {
  StatementRow(
    this.statement, {
    required this.paid,
    required this.matched,
    required this.recorded,
    required String today,
  }) : status = debtDueStatus(statement.values['due'], today),
       days = civilDaysBetween(today, statement.values['due']!);
  final LocalRevision statement;

  /// Payments and credits matched to it through today.
  final BigInt paid;

  /// Activity confirmed as being on it.
  final int matched;

  /// Your records through its last day, by the date each posted.
  final BigInt recorded;
  final DebtDueStatus status;

  /// Calendar days from today to its due date; negative when past it.
  final int days;

  String get id => statement.id;
  String get card => statement.values['card']!;
  String get due => statement.values['due']!;
  String get start => statement.values['start']!;
  String get end => statement.values['end']!;
  BigInt get balance => statement.amount;

  /// Never below zero: a statement in credit has nothing due.
  BigInt get stillDue => _max(balance - paid, BigInt.zero);
  bool get settled => stillDue == BigInt.zero;
  bool get overdue => !settled && days < 0;

  /// Left visible until something explains it (DOMAIN_RULES §12).
  BigInt get difference => balance - recorded;
  BigInt? get minimum {
    final text = statement.values['minimum'] ?? '';
    return text.isEmpty ? null : signedPhp(text);
  }
}

/// A card's statements, newest first.
List<StatementRow> statementRows(LocalSnapshot s, String card, String today) {
  final rows = [
    for (final r in s.current)
      if (financeType(r) == 'statement' && r.values['card'] == card)
        StatementRow(
          r,
          paid: sumMinor(
            s.current
                .where(
                  (a) =>
                      financeType(a) == 'cardAllocation' &&
                      a.date.compareTo(today) <= 0 &&
                      a.values['statement'] == r.id,
                )
                .map((a) => a.amount),
          ),
          matched: s.current
              .where(
                (l) =>
                    financeType(l) == 'statementLink' &&
                    l.values['statement'] == r.id,
              )
              .length,
          recorded: statementRecordedBalance(s, r),
          today: today,
        ),
  ];
  return rows..sort((a, b) {
    final byDate = b.statement.values['issued']!.compareTo(
      a.statement.values['issued']!,
    );
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  });
}

/// One scheduled payment of an installment plan.
class PlanPayment {
  PlanPayment(this.row, this.applied, String today)
    : status = debtDueStatus(row.date, today),
      days = civilDaysBetween(today, row.date);
  final FinanceScheduleRow row;

  /// Matched to this payment through today.
  final BigInt applied;
  final DebtDueStatus status;
  final int days;
  BigInt get paid => row.paid + applied;
  BigInt get left => _max(row.amount - paid, BigInt.zero);
  bool get done => left == BigInt.zero;
}

/// An installment plan and where its payments stand.
class PlanRow {
  PlanRow(this.plan, this.payments);
  final LocalRevision plan;
  final List<PlanPayment> payments;
  String get id => plan.id;
  String get card => plan.values['card']!;
  int get total => payments.length;
  int get done => payments.where((p) => p.done).length;
  BigInt get amount => sumMinor(payments.map((p) => p.row.amount));
  BigInt get left => sumMinor(payments.map((p) => p.left));
  PlanPayment? get next => payments.where((p) => !p.done).firstOrNull;
  bool get finished => next == null;
}

/// A card's installment plans.
List<PlanRow> planRows(LocalSnapshot s, String card, String today) => [
  for (final r in s.current)
    if (financeType(r) == 'installment' && r.values['card'] == card)
      PlanRow(r, [
        for (final row in financeSchedule(r.values['schedule']!))
          PlanPayment(
            row,
            sumMinor(
              s.current
                  .where(
                    (a) =>
                        financeType(a) == 'installmentApplication' &&
                        a.values['plan'] == r.id &&
                        a.values['row'] == row.id &&
                        a.date.compareTo(today) <= 0,
                  )
                  .map((a) => a.amount),
            ),
            today,
          ),
      ]),
];

/// Pending charges no purchase has used yet. They aren't in what you owe.
List<LocalRevision> pendingCharges(LocalSnapshot s, String card) => [
  for (final r in s.current)
    if (financeType(r) == 'cardAuthorization' &&
        r.values['card'] == card &&
        !s.current.any((x) => x.values['authorization'] == r.id))
      r,
];

/// One card as the Cards tab shows it.
class CardRow {
  CardRow(this.card, this.balance, this.limit, this.statements, this.plans);
  final LocalRevision card;

  /// What the card's records add up to through today. Below zero it's a card
  /// credit, which is never debt and never money you have (§18).
  final BigInt balance;

  /// Null when no limit was recorded.
  final BigInt? limit;

  /// Newest first.
  final List<StatementRow> statements;
  final List<PlanRow> plans;

  String get id => card.actionId;
  String get name => card.title;
  String get issuer => card.values['issuer'] ?? '';
  BigInt get owed => _max(balance, BigInt.zero);
  BigInt get credit => _max(-balance, BigInt.zero);
  bool get hasLimit => limit != null && limit! > BigInt.zero;

  /// Limit minus what you owe. A card credit doesn't raise it, and it stops
  /// at zero; [over] says the rest. Null without a limit.
  BigInt? get available =>
      limit == null ? null : _max(limit! - owed, BigInt.zero);
  BigInt get over =>
      limit == null ? BigInt.zero : _max(owed - limit!, BigInt.zero);

  /// Whole basis points of the limit; null for a missing or zero limit.
  int? get usedBasisPoints => hasLimit ? shareBasisPoints(owed, limit!) : null;

  /// The statement the card is working through: the newest one.
  StatementRow? get newest => statements.firstOrNull;
}

List<CardRow> cardRows(LocalSnapshot s, String today) => [
  for (final r in s.current)
    if (financeType(r) == 'creditCard')
      CardRow(
        r,
        -financeBalance(
          s,
          'card_liability',
          'card',
          r.actionId,
          through: today,
        ),
        (r.values['limit'] ?? '').isEmpty
            ? null
            : signedPhp(r.values['limit']!),
        statementRows(s, r.actionId, today),
        planRows(s, r.actionId, today),
      ),
];

/// Totals across cards (DOMAIN_RULES §19).
class CardsSummary {
  CardsSummary(this.cards);
  final List<CardRow> cards;

  BigInt get owed => sumMinor(cards.map((c) => c.owed));
  BigInt get credit => sumMinor(cards.map((c) => c.credit));

  /// Cards with a limit to measure against.
  List<CardRow> get limited => cards.where((c) => c.hasLimit).toList();

  BigInt get available => sumMinor(limited.map((c) => c.available!));

  /// Sum of what's used over sum of limits, never an average of percentages.
  /// Card credit stays out of what's used; missing and zero limits stay out
  /// of both.
  int? get usedBasisPoints {
    final cards = limited;
    return cards.isEmpty
        ? null
        : shareBasisPoints(
            sumMinor(cards.map((c) => c.owed)),
            sumMinor(cards.map((c) => c.limit!)),
          );
  }

  /// Each card's newest statement. An older unpaid statement stays listed
  /// but isn't added in, because a newer one usually includes it.
  BigInt get stillDue =>
      sumMinor(cards.map((c) => c.newest?.stillDue ?? BigInt.zero));
  int get statementsDue =>
      cards.where((c) => !(c.newest?.settled ?? true)).length;
}

/// Each card's positive balance added up at the end of each of the last
/// [months] − 1 months, then through today. A card credit on one card doesn't
/// reduce what's owed on another.
List<(String, BigInt)> cardDebtByMonth(
  LocalSnapshot s,
  String today, {
  int months = 6,
  String? card,
}) {
  BigInt owed(String through) => _owedThrough(s, through, card);
  final ends = <String>[];
  var cursor = monthStart(today);
  for (var i = 1; i < months; i++) {
    final end = addCivilDays(cursor, -1);
    ends.insert(0, end);
    cursor = monthStart(end);
  }
  return [
    for (final d in [...ends, today]) (d, owed(d)),
  ];
}

/// What [card] owes each day from [from] to [to], every day present.
List<(String, BigInt)> cardDebtByDay(
  LocalSnapshot s,
  String card,
  String from,
  String to,
) => [
  for (var d = from; d.compareTo(to) <= 0; d = addCivilDays(d, 1))
    (d, _owedThrough(s, d, card)),
];

BigInt _owedThrough(LocalSnapshot s, String through, String? card) => sumMinor(
  s.current
      .where(
        (r) =>
            financeType(r) == 'creditCard' &&
            (card == null || r.actionId == card),
      )
      .map(
        (c) => _max(
          -financeBalance(
            s,
            'card_liability',
            'card',
            c.actionId,
            through: through,
          ),
          BigInt.zero,
        ),
      ),
);

/// One open statement or installment, with its card's name. Statements and
/// installments are never added together: they can overlap.
class CardDue {
  CardDue(this.item, this.card, this.name);
  final DueItem item;

  /// The card's action id, and its name.
  final String card, name;
  String get id => item.source.id;
  String get source => item.source.source;
  bool get statement => item.source.kind == 'Card statement due';
  String get kind => statement ? 'Statement' : 'Installment';
}

/// Everything open on the cards, overdue first and then by date.
List<CardDue> cardDues(LocalSnapshot s, String today) => [
  for (final r in financialReminderSources(
    s,
    '1900-01-01',
    _farAhead,
    asOf: today,
  ))
    if (r.kind == 'Card statement due' || r.kind == 'Card installment due')
      CardDue(
        DueItem(r, today),
        s.revision(r.source).values['card']!,
        cardName(s, s.revision(r.source).values['card']),
      ),
];

/// What a credit (a payment or refund) has left to match to a statement.
BigInt unmatchedCredit(LocalSnapshot s, LocalRevision credit) => _max(
  sumMinor(
        credit.postings
            .where((p) => p.ledger == 'card_liability')
            .map((p) => p.amount),
      ) -
      sumMinor(
        s.current
            .where(
              (a) =>
                  financeType(a) == 'cardAllocation' &&
                  a.values['payment'] == credit.id,
            )
            .map((a) => a.amount),
      ),
  BigInt.zero,
);

/// Why Cards needs the user.
enum CardNeed { difference, unmatched, overLimit, cardCredit, pending }

typedef CardTask = ({CardNeed need, String title, String subtitle, String id});

/// What needs the user: a newest statement that differs from your records,
/// payments not matched while a statement is still due, a card over its
/// limit, a card credit, and pending charges. Each goes to a page.
List<CardTask> cardTasks(LocalSnapshot s, List<CardRow> cards) => [
  for (final c in cards)
    if (c.newest case final n? when n.difference != BigInt.zero)
      (
        need: CardNeed.difference,
        title: '${n.statement.title} differs from your records',
        subtitle: 'Log what’s missing, or check the statement',
        id: n.id,
      ),
  for (final c in cards)
    if (!(c.newest?.settled ?? true))
      if (_unmatched(s, c.id) case final n when n > 0)
        (
          need: CardNeed.unmatched,
          title: n == 1
              ? '1 payment on ${c.name} isn’t matched'
              : '$n payments on ${c.name} aren’t matched',
          subtitle: 'Match them to a statement to see what’s still due',
          id: c.newest!.id,
        ),
  for (final c in cards)
    if (c.over > BigInt.zero)
      (
        need: CardNeed.overLimit,
        title: '${c.name} is over its limit',
        subtitle: 'Available credit is used up',
        id: c.id,
      ),
  for (final c in cards)
    if (c.credit > BigInt.zero)
      (
        need: CardNeed.cardCredit,
        title: '${c.name} has a card credit',
        subtitle: 'It isn’t money you have',
        id: c.id,
      ),
  for (final c in cards)
    if (pendingCharges(s, c.id).length case final n when n > 0)
      (
        need: CardNeed.pending,
        title: n == 1
            ? '1 pending charge on ${c.name}'
            : '$n pending charges on ${c.name}',
        subtitle: 'Not in what you owe yet',
        id: c.id,
      ),
];

int _unmatched(LocalSnapshot s, String card) => s.current
    .where(
      (r) =>
          r.values['card'] == card &&
          const {'cardPayment', 'cardRefund'}.contains(financeType(r)) &&
          unmatchedCredit(s, r) > BigInt.zero,
    )
    .length;

/// Every kind of record about a card.
const cardRecordTypes = {
  'creditCard',
  'cardAuthorization',
  'cardPurchase',
  'cardPayment',
  'cardRefund',
  'cardFee',
  'cardInterest',
  'statement',
  'statementLink',
  'cardAllocation',
  'installment',
  'installmentApplication',
};

/// Records on a card that a statement can list.
const _statementActivity = {
  'cardPurchase',
  'cardPayment',
  'cardRefund',
  'cardFee',
  'cardInterest',
};

/// The date a record posted, or its own date when none was given.
String postedOn(LocalRevision r) => r.values['postingDate'] ?? r.date;

/// Activity confirmed as being on [statement], in date order.
List<LocalRevision> matchedActivity(LocalSnapshot s, LocalRevision statement) {
  final ids = {
    for (final l in s.current)
      if (financeType(l) == 'statementLink' &&
          l.values['statement'] == statement.id)
        l.values['activity'],
  };
  return s.current.where((r) => ids.contains(r.id)).toList()
    ..sort((a, b) => postedOn(a).compareTo(postedOn(b)));
}

/// Activity on the card that posted in the statement's period and isn't
/// matched to any statement. Dates alone don't put it on the statement, so
/// these stay suggestions until the user confirms one.
List<LocalRevision> unmatchedActivity(
  LocalSnapshot s,
  LocalRevision statement,
) {
  final linked = {
    for (final l in s.current)
      if (financeType(l) == 'statementLink') l.values['activity'],
  };
  return s.current
      .where(
        (r) =>
            _statementActivity.contains(financeType(r)) &&
            r.values['card'] == statement.values['card'] &&
            !linked.contains(r.id) &&
            postedOn(r).compareTo(statement.values['start']!) >= 0 &&
            postedOn(r).compareTo(statement.values['end']!) <= 0,
      )
      .toList()
    ..sort((a, b) => postedOn(a).compareTo(postedOn(b)));
}

/// What a form can prefill when matching [credit] to [statement]: the lesser
/// of what's left on each.
BigInt matchableAmount(
  LocalSnapshot s,
  LocalRevision credit,
  StatementRow statement,
) => _min(unmatchedCredit(s, credit), statement.stillDue);
