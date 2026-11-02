import '../app/overview_data.dart';
import '../local/finance_domain.dart';
import 'debt_data.dart' show paidDownBetween;
import 'money_data.dart';
import 'planning_data.dart';

/// Display-only derivations for Reports (DESIGN_SYSTEM §8, Chat 9). They
/// group, filter and add up exact values the domain already returns, and the
/// CSV's format is unchanged. Dates are civil `YYYY-MM-DD` strings.

String financialCsvCell(String value) {
  final unsafe =
      RegExp(r'^[\s﻿]*[=+\-@]').hasMatch(value) ||
      RegExp(r'^[\t\r\n]').hasMatch(value);
  final safe = unsafe ? "'$value" : value;
  return '"${safe.replaceAll('"', '""')}"';
}

String financialCsv(
  LocalSnapshot s,
  String from,
  String endExclusive, {
  String? account,
  String? category,
}) {
  final rows = <List<String>>[
    [
      'salapiya-financial-postings',
      'version',
      '1',
      'owner',
      s.owner,
      'basis',
      'current immutable revisions; economic posting dates',
    ],
    [
      'source_revision',
      'original_action',
      'revision',
      'economic_date',
      'description',
      'ledger',
      'account',
      'category',
      'amount_minor_exact',
      'status',
    ],
  ];
  for (final r in s.current) {
    for (final p in r.postings.where(
      (p) =>
          p.date.compareTo(from) >= 0 &&
          p.date.compareTo(endExclusive) < 0 &&
          (account == null || p.account == account) &&
          (category == null || p.category == category),
    )) {
      rows.add([
        r.id,
        r.actionId,
        '${r.number}',
        p.date,
        r.title,
        p.ledger,
        p.account ?? '',
        p.category ?? '',
        '${p.amount}',
        'Current evidence; see sync coverage',
      ]);
    }
  }
  return '${rows.map((r) => r.map(financialCsvCell).join(',')).join('\r\n')}\r\n';
}

/// The most days one report covers.
const reportMaxDays = 366;

/// The most days a report's chart still draws by day.
const reportDailyDays = 62;

enum ReportPeriod {
  thisMonth('This month'),
  lastMonth('Last month'),
  last90('Last 90 days'),
  thisYear('This year'),
  custom('Custom');

  const ReportPeriod(this.label);
  final String label;
}

/// What a report covers. [account] and [category] are ids, as postings hold
/// them.
class ReportFilter {
  const ReportFilter({
    this.period = ReportPeriod.thisMonth,
    this.from,
    this.to,
    this.account,
    this.category,
  });
  final ReportPeriod period;

  /// A custom period's first and last day.
  final String? from, to;
  final String? account, category;

  /// The rules' figures have no account or category of their own, so a filter
  /// can leave one of them with no answer. It then says so, never ₱0.00.
  bool get spendingKnown => account == null;
  bool get cashKnown => category == null;
  bool get filtered => account != null || category != null;

  /// Counted on the Filters button.
  int get filters => (account == null ? 0 : 1) + (category == null ? 0 : 1);

  /// The dates covered, both inclusive.
  (String, String) range(String today) => switch (period) {
    ReportPeriod.thisMonth => (monthStart(today), today),
    ReportPeriod.lastMonth => (
      monthStart(lastMonthEnd(today)),
      lastMonthEnd(today),
    ),
    ReportPeriod.last90 => (addCivilDays(today, -89), today),
    ReportPeriod.thisYear => ('${today.substring(0, 4)}-01-01', today),
    ReportPeriod.custom => (from ?? today, to ?? today),
  };

  /// What it's compared with. This month matches the Overview: the same days
  /// of last month. Others take the same number of days just before.
  (String, String) before(String today) {
    if (period == ReportPeriod.thisMonth) return lastMonthSpan(today);
    final (start, end) = range(today);
    final days = civilDaysBetween(start, end) + 1;
    return (addCivilDays(start, -days), addCivilDays(start, -1));
  }

  /// Why these dates can't be shown; null when they can.
  String? problem(String today) {
    final (start, end) = range(today);
    final days = civilDaysBetween(start, end) + 1;
    return days < 1 || days > reportMaxDays
        ? 'A report covers 1 to 366 days. Check its dates.'
        : null;
  }

  ReportFilter copyWith({String? account, String? category}) => ReportFilter(
    period: period,
    from: from,
    to: to,
    account: account ?? this.account,
    category: category ?? this.category,
  );

  /// The same filter with an account or category taken off.
  ReportFilter without({bool account = false, bool category = false}) =>
      ReportFilter(
        period: period,
        from: from,
        to: to,
        account: account ? null : this.account,
        category: category ? null : this.category,
      );
}

/// A period as a label, with its year when that's not the current year.
String reportSpan(String from, String to, String today) {
  final label = periodHeading(from, to);
  return RegExp(r'\d{4}$').hasMatch(label) ||
          from.substring(0, 4) == today.substring(0, 4)
      ? label
      : '$label ${from.substring(0, 4)}';
}

/// Spending per calendar month of the period, the first and last months cut
/// to it, every month present.
List<(String, BigInt)> monthlySpending(
  LocalSnapshot s,
  String from,
  String to, {
  String? category,
}) {
  final months = <String, BigInt>{};
  for (
    var month = monthStart(from);
    month.compareTo(to) <= 0;
    month = addCivilDays(monthEnd(month), 1)
  ) {
    months[month] = BigInt.zero;
  }
  for (final (day, value) in dailySpending(s, from, to, category: category)) {
    final month = monthStart(day);
    months[month] = months[month]! + value;
  }
  return [for (final e in months.entries) (e.key, e.value)];
}

/// One category's net spending against the earlier period.
class CategoryChange {
  CategoryChange(this.name, this.current, this.previous);
  final String name;
  final BigInt current, previous;
  BigInt get change => current - previous;
  int? get basisPoints => changeBasisPoints(current, previous);
}

/// Every category with spending in either period, largest first. Refunds
/// larger than spending leave a category below zero, and it stays that way.
List<CategoryChange> categoryChanges(
  LocalSnapshot s,
  (String, String) period,
  (String, String) before,
  String Function(String?) name, {
  String? only,
}) {
  final now = {
    for (final (label, value) in spendingByCategory(
      s,
      period.$1,
      period.$2,
      name,
    ))
      label: value,
  };
  final earlier = {
    for (final (label, value) in spendingByCategory(
      s,
      before.$1,
      before.$2,
      name,
    ))
      label: value,
  };
  return [
    for (final label in {...now.keys, ...earlier.keys})
      if (only == null || label == only)
        if ((now[label] ?? BigInt.zero) != BigInt.zero ||
            (earlier[label] ?? BigInt.zero) != BigInt.zero)
          CategoryChange(
            label,
            now[label] ?? BigInt.zero,
            earlier[label] ?? BigInt.zero,
          ),
  ]..sort((a, b) {
    final byAmount = b.current.compareTo(a.current);
    return byAmount != 0 ? byAmount : a.name.compareTo(b.name);
  });
}

/// What moved on cards, debts and groups in a period. Amounts are shown as
/// positive, except the group movements and [unexplained], which can go
/// either way.
class CardSummary {
  const CardSummary({
    required this.purchases,
    required this.payments,
    required this.charges,
    required this.refunds,
    required this.paidDown,
    required this.groupOwedToYou,
    required this.groupYouOwe,
    required this.unexplained,
  });
  final BigInt purchases, payments, refunds, paidDown;

  /// Card fees and interest.
  final BigInt charges;
  final BigInt groupOwedToYou, groupYouOwe;

  /// Debt payments still waiting for a breakdown.
  final BigInt unexplained;
}

/// [cardSummary]'s figures come from the same postings as what you owe on a
/// card: a card's starting balance isn't activity, and a shared purchase paid
/// by card counts as a purchase.
CardSummary cardSummary(LocalSnapshot s, String from, String to) {
  var purchases = BigInt.zero, payments = BigInt.zero;
  var charges = BigInt.zero, refunds = BigInt.zero;
  bool inside(LocalPosting p) =>
      p.date.compareTo(from) >= 0 && p.date.compareTo(to) <= 0;
  for (final r in s.current) {
    final type = financeType(r);
    if (type == 'creditCard') continue;
    final moved = sumMinor(
      r.postings
          .where((p) => p.ledger == 'card_liability' && inside(p))
          .map((p) => p.amount),
    );
    if (type == 'cardPayment') {
      payments += moved;
    } else if (type == 'cardFee' || type == 'cardInterest') {
      charges -= moved;
    } else if (moved < BigInt.zero) {
      purchases -= moved;
    } else {
      refunds += moved;
    }
  }
  BigInt movement(String ledger) => sumMinor(
    s.current
        .expand((r) => r.postings)
        .where((p) => p.ledger == ledger && inside(p))
        .map((p) => p.amount),
  );
  return CardSummary(
    purchases: purchases,
    payments: payments,
    charges: charges,
    refunds: refunds,
    paidDown: paidDownBetween(s, from, to),
    groupOwedToYou: movement('shared_receivable'),
    groupYouOwe: -movement('shared_payable'),
    unexplained: movement('debt_clearing'),
  );
}

/// Budgets whose own period touches this one, each with its whole period's
/// spending. They're never cut to the report's dates and never added up.
/// Archived budgets stay out, as they do on Planning.
List<(BudgetWhen, BudgetProgress)> reportBudgets(
  LocalSnapshot s,
  String from,
  String to,
  String today, {
  String? category,
}) => [
  for (final (period, b) in budgetRows(s, today))
    if (period != BudgetWhen.archived &&
        b.budget.values['start']!.compareTo(to) <= 0 &&
        b.budget.values['endExclusive']!.compareTo(from) > 0 &&
        (category == null || b.budget.values['category'] == category))
      (period, b),
];

/// One row per record the report covers. Reversed records have no effect
/// left, so they stay in Activity only.
List<MoneyRow> reportRecords(
  Iterable<MoneyRow> rows,
  ReportFilter filter,
  String today,
  String Function(String?) categoryName,
) {
  final (from, to) = filter.range(today);
  final narrow = ActivityFilter(
    period: ActivityPeriod.custom,
    from: from,
    to: to,
    account: filter.account,
    category: filter.category == null ? null : categoryName(filter.category),
  );
  return [
    for (final r in rows)
      if (!r.reversed && narrow.shows(r, today)) r,
  ];
}
