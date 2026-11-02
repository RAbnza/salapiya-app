import '../app/overview_data.dart';
import '../local/finance_domain.dart';
import 'money_data.dart';

/// Display-only derivations for Planning (DESIGN_SYSTEM §8, Chat 9). They
/// group, filter and add up exact values the domain already returns, and
/// every definition here is the rules' own. Dates are civil `YYYY-MM-DD`
/// strings.

/// The last day of a period the records store with an exclusive end.
String lastDay(String endExclusive) => addCivilDays(endExclusive, -1);

/// When a budget applies.
enum BudgetWhen {
  current('Current'),
  later('Later'),
  past('Past'),
  archived('Archived');

  const BudgetWhen(this.label);
  final String label;
}

/// "October 2026", or its first to last day.
String budgetPeriodLabel(LocalRevision budget) => periodHeading(
  budget.values['start']!,
  lastDay(budget.values['endExclusive']!),
);

BudgetWhen budgetWhen(LocalRevision budget, String today) {
  final v = budget.values;
  return v['status'] != 'active'
      ? BudgetWhen.archived
      : v['start']!.compareTo(today) > 0
      ? BudgetWhen.later
      : v['endExclusive']!.compareTo(today) <= 0
      ? BudgetWhen.past
      : BudgetWhen.current;
}

/// Every budget with its whole-period spending: current first, then later,
/// past and archived, each newest period first.
List<(BudgetWhen, BudgetProgress)> budgetRows(LocalSnapshot s, String today) {
  final rows = [
    for (final b in s.current.where((r) => financeType(r) == 'budget'))
      (budgetWhen(b, today), BudgetProgress(b, budgetSpending(s, b))),
  ];
  return rows..sort((a, b) {
    final byWhen = a.$1.index.compareTo(b.$1.index);
    return byWhen != 0
        ? byWhen
        : b.$2.budget.values['start']!.compareTo(a.$2.budget.values['start']!);
  });
}

/// Whether [budgets] can be added up: the rules allow no total across mixed
/// periods or bases.
bool sameBudgetTerms(Iterable<BudgetProgress> budgets) {
  final terms = {
    for (final b in budgets)
      (
        b.budget.values['start'],
        b.budget.values['endExclusive'],
        b.budget.values['basis'],
      ),
  };
  return terms.length <= 1;
}

/// Where a goal's money stands (DOMAIN_RULES V2-D).
enum GoalFunding {
  funded('Fully funded'),
  partly('Partly funded'),
  shared('Shared shortfall'),
  none('Not funded');

  const GoalFunding(this.label);
  final String label;
}

/// One savings goal, with the exact supported funding range.
class GoalRow {
  GoalRow(this.goal, this.reserved, this.low, this.high);
  final LocalRevision goal;

  /// Set aside for it, whatever your accounts hold now.
  final BigInt reserved;

  /// The least and most of [reserved] your accounts can support. They differ
  /// when goals share an account that's short: no goal wins automatically.
  final BigInt low, high;

  String get id => goal.actionId;
  BigInt get target => goal.amount;
  String get status => goal.values['status'] ?? 'active';
  String? get targetDate {
    final date = goal.values['targetDate'] ?? '';
    return date.isEmpty ? null : date;
  }

  /// Fully funded needs the low bound to meet the target; not funded means
  /// the high bound is zero. Otherwise it's partly funded, or uncertain when
  /// the range isn't one figure.
  GoalFunding get funding => low >= target
      ? GoalFunding.funded
      : high == BigInt.zero
      ? GoalFunding.none
      : low != high
      ? GoalFunding.shared
      : GoalFunding.partly;

  /// Set aside as a share of the target, in whole basis points.
  int? get basisPoints => shareBasisPoints(reserved, target);

  /// Above the target: a target can be lowered below what's set aside.
  BigInt get excess => reserved > target ? reserved - target : BigInt.zero;
}

GoalRow goalRow(LocalSnapshot s, LocalRevision goal, String today) {
  final (low, high) = supportedSavings(s, goal.actionId, today);
  return GoalRow(goal, savingsReserved(s, goal: goal.actionId), low, high);
}

/// Active goals first, then completed, then archived.
List<GoalRow> goalRows(LocalSnapshot s, String today) {
  const order = ['active', 'completed', 'archived'];
  final rows = [
    for (final g in s.current.where((r) => financeType(r) == 'savingsGoal'))
      goalRow(s, g, today),
  ];
  return rows..sort(
    (a, b) => order.indexOf(a.status).compareTo(order.indexOf(b.status)),
  );
}

/// What a goal has set aside in one account.
class GoalAccount {
  GoalAccount(this.account, this.reserved, this.others, this.eligible);
  final LocalAccount account;
  final BigInt reserved;

  /// Set aside there for other goals.
  final BigInt others;

  /// What the account can support: its balance today, never below zero.
  final BigInt eligible;

  /// How far the account falls short of everything set aside in it.
  BigInt get shortfall {
    final gap = reserved + others - eligible;
    return gap > BigInt.zero ? gap : BigInt.zero;
  }
}

List<GoalAccount> goalAccounts(LocalSnapshot s, String goal, String today) => [
  for (final a in s.accounts)
    if (savingsReserved(s, goal: goal, account: a.id) case final held
        when held != BigInt.zero)
      GoalAccount(
        a,
        held,
        savingsReserved(s, account: a.id) - held,
        eligibleSavings(s, a.id, today),
      ),
];

/// "Monthly on the 1st", "Every 2 weeks on Mon, Wed", "Every 3 days".
String recurringLabel(LocalRevision rule) {
  final v = rule.values;
  final every = int.tryParse(v['interval'] ?? '') ?? 1;
  String ordinal(int n) {
    final tens = n % 100;
    if (tens >= 11 && tens <= 13) return '${n}th';
    return '$n${const {1: 'st', 2: 'nd', 3: 'rd'}[n % 10] ?? 'th'}';
  }

  const days = {
    '1': 'Mon',
    '2': 'Tue',
    '3': 'Wed',
    '4': 'Thu',
    '5': 'Fri',
    '6': 'Sat',
    '7': 'Sun',
  };
  final weekdays = (v['weekdays'] ?? '')
      .split(',')
      .map((d) => days[d])
      .nonNulls
      .join(', ');
  return switch (v['frequency']) {
    'daily' => every == 1 ? 'Every day' : 'Every $every days',
    'weekly' => '${every == 1 ? 'Weekly' : 'Every $every weeks'} on $weekdays',
    _ =>
      '${every == 1 ? 'Monthly' : 'Every $every months'} on the ${ordinal(int.tryParse(v['monthDay'] ?? '') ?? 1)}',
  };
}

String recurringKindLabel(String? kind) => switch (kind) {
  'income' => 'Expected income',
  'subscription' => 'Subscription',
  _ => 'Bill',
};

/// A recurring date's state in everyday words.
String dateStateLabel(String state) => switch (state) {
  'linked' => 'Part linked',
  'completed' => 'Done',
  'skipped' => 'Skipped',
  'cancelled' => 'Cancelled',
  _ => 'Expected',
};

/// One recurring item as the Planning table shows it.
class RecurringRow {
  RecurringRow(this.rule, this.next, this.added);
  final LocalRevision rule;

  /// The next date still open, from today.
  final RecurringOccurrence? next;

  /// Whether any of the next 90 days' dates are saved, so they count in dues.
  final bool added;

  String get id => rule.id;
  bool get active => rule.values['status'] == 'active';
  bool get income => rule.values['recurringKind'] == 'income';
}

const _openStates = {'planned', 'linked'};

/// Every current recurring item, active ones first, then by next date.
List<RecurringRow> recurringRows(LocalSnapshot s, String today) {
  final dates = recurringOccurrences(
    s,
    today,
    addCivilDays(today, 365),
    previews: true,
  ).where((o) => _openStates.contains(o.state)).toList();
  final near = addCivilDays(today, 89);
  final rows = [
    for (final rule in s.current.where((r) => financeType(r) == 'recurrence'))
      () {
        final own = dates.where((o) => o.rule.actionId == rule.actionId);
        return RecurringRow(
          rule,
          own.firstOrNull,
          own.any((o) => o.persisted && o.due.compareTo(near) <= 0),
        );
      }(),
  ];
  return rows..sort((a, b) {
    if (a.active != b.active) return a.active ? -1 : 1;
    final an = a.next?.due, bn = b.next?.due;
    if (an == null || bn == null) {
      return an == bn
          ? a.rule.title.compareTo(b.rule.title)
          : (an == null ? 1 : -1);
    }
    return an.compareTo(bn);
  });
}

/// One item's dates: saved ones, however old, then the next 90 days of those
/// not added yet. Newest last.
List<RecurringOccurrence> recurringDatesFor(
  LocalSnapshot s,
  LocalRevision rule,
  String today,
) {
  final saved = recurringOccurrences(
    s,
    '1900-01-01',
    '2199-12-31',
  ).where((o) => o.rule.actionId == rule.actionId);
  final ahead = recurringOccurrences(
    s,
    today,
    addCivilDays(today, 89),
    previews: true,
  ).where((o) => o.rule.actionId == rule.actionId && !o.persisted);
  return [...saved, ...ahead]..sort((a, b) => a.due.compareTo(b.due));
}

/// One thing coming up. [expected] marks a recurring date not added yet.
class UpcomingRow {
  UpcomingRow({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.kind,
    required this.source,
    required this.income,
    required this.expected,
    required String today,
  }) : days = civilDaysBetween(today, date);
  final String id, title, date, kind, source;
  final BigInt amount;
  final bool income, expected;
  final int days;
}

/// The next [days] days from today: what's due, then recurring dates not
/// added yet. There's no total: a statement and its installments can overlap.
List<UpcomingRow> upcomingRows(LocalSnapshot s, String today, {int days = 30}) {
  final end = addCivilDays(today, days - 1);
  final rows = <UpcomingRow>[
    for (final r in namedDueSources(
      s,
      financialReminderSources(s, today, end, asOf: today),
    ))
      UpcomingRow(
        id: r.id,
        title: r.title,
        date: r.date,
        amount: r.amount,
        kind: switch (r.kind) {
          'Debt due' => 'Debt',
          'Card statement due' => 'Card statement',
          'Card installment due' => 'Card installment',
          _ => recurringKindLabel(s.revision(r.source).values['recurringKind']),
        },
        source: r.source,
        income: s.revision(r.source).values['recurringKind'] == 'income',
        expected: false,
        today: today,
      ),
    for (final o in recurringOccurrences(s, today, end, previews: true))
      if (!o.persisted &&
          _openStates.contains(o.state) &&
          o.remaining > BigInt.zero)
        UpcomingRow(
          id: 'preview:${o.id}',
          title: o.rule.title,
          date: o.due,
          amount: o.remaining,
          kind: recurringKindLabel(o.rule.values['recurringKind']),
          source: o.rule.id,
          income: o.rule.values['recurringKind'] == 'income',
          expected: true,
          today: today,
        ),
  ];
  return rows..sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.title.compareTo(b.title);
  });
}

/// The default forecast: tomorrow through 30 days from today, with no card
/// payment assumed. Null if the rules can't cover it.
FinanceForecast? defaultForecast(LocalSnapshot s, String today) {
  try {
    return financialForecast(
      s,
      today: today,
      from: addCivilDays(today, 1),
      through: addCivilDays(today, 30),
    );
  } on LocalRuleException {
    return null;
  }
}

/// The lowest closing day of a forecast.
(String, BigInt)? lowestDay(FinanceForecast forecast) {
  (String, BigInt)? low;
  for (final e in forecast.daily.entries) {
    if (low == null || e.value < low.$2) low = (e.key, e.value);
  }
  return low;
}

/// What Planning's tiles say.
class PlanningSummary {
  PlanningSummary(this.budgets, this.goals, this.upcoming);
  final List<BudgetProgress> budgets;
  final List<GoalRow> goals;
  final List<UpcomingRow> upcoming;

  /// Budgets with a limit to be within: zero-limit ones aren't counted.
  List<BudgetProgress> get limited =>
      budgets.where((b) => b.limit != BigInt.zero).toList();
  int get overLimit => budgets.where((b) => b.overLimit).length;
  int get withinLimit => limited.length - overLimit;
  List<GoalRow> get activeGoals =>
      goals.where((g) => g.status == 'active').toList();
}
