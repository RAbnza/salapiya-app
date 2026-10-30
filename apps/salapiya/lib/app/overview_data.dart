import '../local/finance_domain.dart';

/// Display-only derivations for the Overview (DESIGN_SYSTEM §8, Chat 6).
/// They group, count and add up exact values the domain already returns;
/// statuses come from `debtDueStatus`, and no money rule lives here. Dates
/// are civil `YYYY-MM-DD` strings, as `civilToday()` gives them.

DateTime _day(String date) => DateTime.parse('${date}T00:00:00Z');
String _iso(DateTime day) => day.toIso8601String().substring(0, 10);

String addCivilDays(String date, int days) =>
    _iso(_day(date).add(Duration(days: days)));

/// Calendar days from [from] to [to]; negative when [to] is earlier.
int civilDaysBetween(String from, String to) =>
    _day(to).difference(_day(from)).inDays;

String monthStart(String date) => '${date.substring(0, 7)}-01';

String monthEnd(String date) {
  final d = _day(date);
  return _iso(DateTime.utc(d.year, d.month + 1, 0));
}

/// The period toggle on the dues card.
enum DuePeriod {
  week('This week'),
  month('This month');

  const DuePeriod(this.label);
  final String label;
}

/// W1: Monday to Sunday (ISO week). W2: the calendar month. Both inclusive.
(String, String) duePeriodRange(String today, DuePeriod period) =>
    switch (period) {
      DuePeriod.week => (
        addCivilDays(today, 1 - _day(today).weekday),
        addCivilDays(today, 7 - _day(today).weekday),
      ),
      DuePeriod.month => (monthStart(today), monthEnd(today)),
    };

/// One unpaid due row with the existing status rule applied.
class DueItem {
  DueItem(this.source, String today)
    : status = debtDueStatus(source.date, today),
      days = civilDaysBetween(today, source.date);
  final FinancialReminderSource source;
  final DebtDueStatus status;

  /// Calendar days from today; negative when overdue.
  final int days;
  String get date => source.date;
  BigInt get amount => source.amount;
}

/// What is due, split for the dues card. W3: the period list starts today;
/// anything earlier is only under [overdue], however old.
class OverviewDues {
  OverviewDues._(
    this.today,
    this.period,
    this.start,
    this.end,
    this.overdue,
    this.upcoming,
  );

  factory OverviewDues.from(
    Iterable<FinancialReminderSource> sources,
    String today,
    DuePeriod period,
  ) {
    final (start, end) = duePeriodRange(today, period);
    final sorted = sources.toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.title.compareTo(b.title);
      });
    return OverviewDues._(
      today,
      period,
      start,
      end,
      [
        for (final s in sorted)
          if (s.date.compareTo(today) < 0) DueItem(s, today),
      ],
      [
        for (final s in sorted)
          if (s.date.compareTo(today) >= 0 && s.date.compareTo(end) <= 0)
            DueItem(s, today),
      ],
    );
  }

  final String today, start, end;
  final DuePeriod period;
  final List<DueItem> overdue, upcoming;

  BigInt get overdueTotal => sumMinor(overdue.map((i) => i.amount));
  BigInt get upcomingTotal => sumMinor(upcoming.map((i) => i.amount));
  bool get isEmpty => overdue.isEmpty && upcoming.isEmpty;

  /// Every day of the period, each with its rows (overdue ones included), for
  /// the calendar strip.
  List<(String, List<DueItem>)> get days => [
    for (var d = start; d.compareTo(end) <= 0; d = addCivilDays(d, 1))
      (d, [...overdue, ...upcoming].where((i) => i.date == d).toList()),
  ];
}

/// Everything unpaid due on or before the later of the two period ends.
/// Overdue rows have no lookback limit (W3); 1900 is the planning minimum.
List<FinancialReminderSource> overviewDueSources(
  LocalSnapshot s,
  String today,
) {
  final week = duePeriodRange(today, DuePeriod.week).$2;
  final month = monthEnd(today);
  return financialReminderSources(
    s,
    '1900-01-01',
    week.compareTo(month) > 0 ? week : month,
    asOf: today,
  );
}

/// Payoff progress for one debt, by its payment schedule.
class DebtProgress {
  DebtProgress(this.debt, this.due, this.outstanding)
    : rows = due.schedule == null
          ? const []
          : financeSchedule(due.schedule!.values['schedule']!);
  final LocalRevision debt;
  final DebtDueSummary due;

  /// Recognized balance through today; not part of the schedule maths.
  final BigInt outstanding;
  final List<FinanceScheduleRow> rows;

  bool get scheduled => due.schedule != null;
  bool get closed => due.closed;

  /// Nothing left on the schedule: every payment logged, or closed by payoff.
  bool get finished => scheduled && due.open.isEmpty;
  int get total => rows.length;
  int get done => total - due.open.length;
  BigInt get scheduledTotal => sumMinor(rows.map((r) => r.amount));
  BigInt get scheduledLeft => sumMinor(due.open.map((o) => o.$2));

  /// Share of the scheduled amount covered, for the bar only. Null without a
  /// schedule. A closed debt shows a full bar.
  double? get fraction => !scheduled
      ? null
      : finished
      ? 1
      : scheduledTotal == BigInt.zero
      ? 0
      : (scheduledTotal - scheduledLeft) / scheduledTotal;

  /// The pill label: the debt status, or "Settled"/"Closed" as on Debts.
  String get statusLabel =>
      due.status?.label ?? (closed ? 'Closed' : 'Settled');
}

List<DebtProgress> overviewDebtProgress(LocalSnapshot s, String today) {
  final result = [
    for (final debt in s.current.where(
      (r) => ['debtImport', 'borrowing'].contains(financeType(r)),
    ))
      DebtProgress(
        debt,
        debtDueSummary(s, debt, today),
        -financeBalance(
          s,
          'debt_liability',
          'debt',
          debt.actionId,
          through: today,
        ),
      ),
  ];
  return result..sort((a, b) => compareDebtUrgency(a.due, b.due));
}

Iterable<LocalPosting> _expenses(LocalSnapshot s, String from, String to) => s
    .current
    .expand((r) => r.postings)
    .where(
      (p) =>
          p.ledger == 'expense' &&
          p.date.compareTo(from) >= 0 &&
          p.date.compareTo(to) <= 0,
    );

BigInt spendingBetween(LocalSnapshot s, String from, String to) =>
    sumMinor(_expenses(s, from, to).map((p) => p.amount));

/// Income in the range; borrowed money posts to debt, so it isn't income.
BigInt incomeBetween(LocalSnapshot s, String from, String to) => -sumMinor(
  s.current
      .expand((r) => r.postings)
      .where(
        (p) =>
            p.ledger == 'income' &&
            p.date.compareTo(from) >= 0 &&
            p.date.compareTo(to) <= 0,
      )
      .map((p) => p.amount),
);

/// Net spending per category, largest first, as today's Overview groups it.
List<(String, BigInt)> spendingByCategory(
  LocalSnapshot s,
  String from,
  String to,
  String Function(String?) name,
) {
  final totals = <String, BigInt>{};
  for (final p in _expenses(s, from, to)) {
    final label = name(p.category);
    totals[label] = (totals[label] ?? BigInt.zero) + p.amount;
  }
  return [for (final e in totals.entries) (e.key, e.value)]
    ..sort((a, b) => b.$2.compareTo(a.$2));
}

/// O4: each day's net spending from [from] to [to], every day present.
List<(String, BigInt)> dailySpending(LocalSnapshot s, String from, String to) {
  final totals = <String, BigInt>{};
  for (final p in _expenses(s, from, to)) {
    totals[p.date] = (totals[p.date] ?? BigInt.zero) + p.amount;
  }
  return [
    for (var d = from; d.compareTo(to) <= 0; d = addCivilDays(d, 1))
      (d, totals[d] ?? BigInt.zero),
  ];
}

/// O5: spending from the 1st through today against the same days of last
/// month. Last month's span stops at its last day when it is shorter.
class SpendingComparison {
  SpendingComparison(LocalSnapshot s, this.today)
    : previousStart = monthStart(addCivilDays(monthStart(today), -1)),
      previousEnd = _sameDayLastMonth(today) {
    current = dailySpending(s, monthStart(today), today);
    previous = dailySpending(s, previousStart, previousEnd);
  }
  final String today, previousStart, previousEnd;
  late final List<(String, BigInt)> current, previous;

  BigInt get currentTotal => sumMinor(current.map((d) => d.$2));
  BigInt get previousTotal => sumMinor(previous.map((d) => d.$2));
  BigInt get difference => currentTotal - previousTotal;

  /// Running totals by day of the month, for the two lines.
  static List<BigInt> running(List<(String, BigInt)> days) {
    var total = BigInt.zero;
    return [for (final d in days) total += d.$2];
  }

  static String _sameDayLastMonth(String today) {
    final end = addCivilDays(monthStart(today), -1);
    final day = today.substring(8);
    return day.compareTo(end.substring(8)) <= 0
        ? '${end.substring(0, 8)}$day'
        : end;
  }
}

/// O6: what you owe at the end of each of the last [months] − 1 months, then
/// through today. Same postings as `debtTotal`.
List<(String, BigInt)> debtBalanceByMonth(
  LocalSnapshot s,
  String today, {
  int months = 6,
}) {
  final postings = s.current
      .expand((r) => r.postings)
      .where((p) => p.ledger == 'debt_liability')
      .toList();
  BigInt owed(String through) => -sumMinor(
    postings.where((p) => p.date.compareTo(through) <= 0).map((p) => p.amount),
  );
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

/// O8: an active budget covering today, with its spending.
class BudgetProgress {
  BudgetProgress(this.budget, this.spent);
  final LocalRevision budget;
  final BigInt spent;
  BigInt get limit => budget.amount;
  BigInt get remaining => limit - spent;
  BigInt get over => spent > limit ? spent - limit : BigInt.zero;

  /// Exact integer basis points (DOMAIN_RULES planning); null for a zero
  /// limit, which has no percentage denominator.
  int? get basisPoints => limit == BigInt.zero
      ? null
      : (spent * BigInt.from(10000) ~/ limit).toInt();
}

List<BudgetProgress> activeBudgets(LocalSnapshot s, String today) => [
  for (final b in s.current.where(
    (r) =>
        financeType(r) == 'budget' &&
        r.values['status'] == 'active' &&
        r.values['start']!.compareTo(today) <= 0 &&
        r.values['endExclusive']!.compareTo(today) > 0,
  ))
    BudgetProgress(b, budgetSpending(s, b)),
];

/// Each day's closing balance of [accounts] from [from] to [to]: the same
/// postings as `LocalSnapshot.balance`, so the last value of all accounts is
/// the available money shown today.
List<(String, BigInt)> balanceByDay(
  LocalSnapshot s,
  Iterable<String> accounts,
  String from,
  String to,
) {
  final ids = accounts.toSet();
  final postings = s.current
      .expand((r) => r.postings)
      .where((p) => ids.contains(p.account))
      .toList();
  var total = sumMinor(
    postings.where((p) => p.date.compareTo(from) < 0).map((p) => p.amount),
  );
  final byDay = <String, BigInt>{};
  for (final p in postings.where((p) => p.date.compareTo(from) >= 0)) {
    byDay[p.date] = (byDay[p.date] ?? BigInt.zero) + p.amount;
  }
  return [
    for (var d = from; d.compareTo(to) <= 0; d = addCivilDays(d, 1))
      (d, total += byDay[d] ?? BigInt.zero),
  ];
}

/// Each day's income from [from] to [to], every day present.
List<(String, BigInt)> dailyIncome(LocalSnapshot s, String from, String to) => [
  for (var d = from; d.compareTo(to) <= 0; d = addCivilDays(d, 1))
    (d, incomeBetween(s, d, d)),
];

/// The change from [previous] to [current] in whole basis points of
/// [previous], rounded toward zero. Null when [previous] is zero, which has
/// no percentage.
int? changeBasisPoints(BigInt current, BigInt previous) =>
    previous == BigInt.zero
    ? null
    : ((current - previous) * BigInt.from(10000) ~/ previous.abs()).toInt();

/// [part] of [whole] in whole basis points, rounded down; null for a zero or
/// negative [whole].
int? shareBasisPoints(BigInt part, BigInt whole) =>
    whole <= BigInt.zero ? null : (part * BigInt.from(10000) ~/ whole).toInt();

/// "4.2%": basis points with one decimal, rounded toward zero, no sign.
String percentLabel(int basisPoints) {
  final bp = basisPoints.abs();
  return '${bp ~/ 100}.${bp % 100 ~/ 10}%';
}

/// Spending per category for the donut: the [top] largest positive ones,
/// then the rest as "Other". Net-negative categories (refunds larger than
/// spending) are left out of the shares.
List<(String, BigInt)> categoryShares(
  List<(String, BigInt)> categories, {
  int top = 5,
}) {
  final positive = categories.where((c) => c.$2 > BigInt.zero).toList();
  if (positive.length <= top + 1) return positive;
  return [
    ...positive.take(top),
    ('Other', sumMinor(positive.skip(top).map((c) => c.$2))),
  ];
}

/// Spending and limits of the active budgets that have a limit, for the
/// gauge. Basis points are null when there is no limit to measure against.
({BigInt spent, BigInt limit, int? basisPoints}) budgetTotals(
  List<BudgetProgress> budgets,
) {
  final limited = budgets.where((b) => b.limit > BigInt.zero);
  final spent = sumMinor(limited.map((b) => b.spent));
  final limit = sumMinor(limited.map((b) => b.limit));
  return (
    spent: spent,
    limit: limit,
    basisPoints: shareBasisPoints(spent, limit),
  );
}

/// The largest single expenses from [from] to [to], largest first, each
/// with its net spending in the range.
List<(LocalRevision, BigInt)> largestExpenses(
  LocalSnapshot s,
  String from,
  String to, {
  int count = 5,
}) {
  BigInt spent(LocalRevision r) => sumMinor(
    r.postings
        .where(
          (p) =>
              p.ledger == 'expense' &&
              p.date.compareTo(from) >= 0 &&
              p.date.compareTo(to) <= 0,
        )
        .map((p) => p.amount),
  );
  final list =
      [for (final r in s.current) (r, spent(r))]
          .where((e) => e.$2 > BigInt.zero)
          .toList()
        ..sort((a, b) => b.$2.compareTo(a.$2));
  return list.take(count).toList();
}

/// O12: short plain sentences from the values above. [amount] is the
/// session's formatter, so hidden amounts stay hidden.
List<String> overviewInsights({
  required OverviewDues week,
  required SpendingComparison? comparison,
  required List<(String, BigInt)> categories,
  required List<BudgetProgress> budgets,
  required String Function(BigInt) amount,
}) {
  String count(int n, String one, String many) => n == 1 ? one : many;
  final overBudget = budgets.where((b) => b.over > BigInt.zero).length;
  final top = categories.where((c) => c.$2 > BigInt.zero).firstOrNull;
  return [
    if (week.overdue.isNotEmpty)
      '${week.overdue.length} ${count(week.overdue.length, 'payment is', 'payments are')} overdue, ${amount(week.overdueTotal)} in total.',
    if (week.upcoming.isNotEmpty)
      '${week.upcoming.length} ${count(week.upcoming.length, 'payment is', 'payments are')} due by Sunday, ${amount(week.upcomingTotal)} in total.',
    if (comparison != null && comparison.difference != BigInt.zero)
      'You have spent ${amount(comparison.difference.abs())} ${comparison.difference > BigInt.zero ? 'more' : 'less'} than by this day last month.',
    if (top != null) 'Your largest spending category this month is ${top.$1}.',
    if (overBudget > 0)
      '$overBudget ${count(overBudget, 'budget is', 'budgets are')} over the limit.',
  ];
}
