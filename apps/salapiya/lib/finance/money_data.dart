import 'package:flutter/material.dart' show IconData, Icons;

import '../app/overview_cards.dart' show civilLabel, overviewSpan;
import '../app/overview_data.dart';
import '../design_system/kit/fields.dart' show DateField;
import '../local/finance_domain.dart';
import 'files_data.dart' show FileAccess;

/// Display-only derivations for Money (DESIGN_SYSTEM §8, Chat 8). They group,
/// filter and add up exact values the domain already returns, and no money
/// rule lives here. Dates are civil `YYYY-MM-DD` strings.

/// The kinds of record Activity can narrow to.
enum ActivityType {
  all('All'),
  moneyOut('Money out'),
  moneyIn('Money in'),
  transfers('Transfers'),
  cards('Cards'),
  debts('Debts'),
  adjustments('Adjustments');

  const ActivityType(this.label);
  final String label;
}

/// Whether a record was changed after it was logged.
enum RecordChange { none, corrected, reversed }

/// What a stored record type is, in everyday words.
String moneyLabel(LocalRevision r) {
  if (r.values.containsKey('sharedGroup')) {
    return switch (r.kind) {
      'refund' => 'Shared refund',
      'adjustment' => 'Shared payment',
      _ => 'Shared expense',
    };
  }
  return switch (financeType(r)) {
    'expense' => 'Expense',
    'income' => 'Income',
    'transfer' => 'Transfer',
    'refund' => 'Refund',
    'adjustment' => 'Balance adjustment',
    'opening' => 'Opening balance',
    'reconcile' => 'Balance check',
    'cardPurchase' => 'Card purchase',
    'cardPayment' => 'Card payment',
    'cardRefund' => 'Card refund',
    'cardFee' => 'Card fee',
    'cardInterest' => 'Card interest',
    'debtPayment' => 'Debt payment',
    'debtPayoff' => 'Early payoff',
    'debtClassification' => 'Payment breakdown',
    'debtAdjustment' => 'Lender charge or waiver',
    'borrowing' => 'New loan',
    'debtImport' => 'Debt',
    'debtSchedule' => 'Payment schedule',
    'creditCard' => 'Credit card',
    'cardAuthorization' => 'Pending charge',
    'statement' => 'Card statement',
    'statementLink' => 'Activity matched to a statement',
    'cardAllocation' => 'Payment matched to a statement',
    'installment' => 'Installment plan',
    'installmentApplication' => 'Payment matched to an installment',
    'budget' => 'Budget',
    'savingsGoal' => 'Savings goal',
    'reservation' => 'Money set aside',
    'savingsReallocation' => 'Money moved between goals',
    'recurrence' => 'Recurring item',
    'recurrenceGenerate' => 'Dates added to Upcoming',
    'occurrenceOverride' => 'Recurring date changed',
    'recurrenceLink' => 'Record linked to a recurring date',
    'recurrenceUnlink' => 'Link removed',
    'financialFile' => 'Attachment',
    'fileDetach' => 'Attachment link archived',
    'cashImport' ||
    'cashImportChunk' ||
    'cashImportPreview' ||
    'cashImportDecision' ||
    'cashImportProcess' ||
    'cashImportCancel' ||
    'cashOpeningRebase' => 'Import',
    _ => 'Record',
  };
}

/// A record's title for the eye. Stored titles stay as they were saved.
String recordTitle(LocalRevision r) => r.title.startsWith('Reconciliation · ')
    ? r.title.replaceFirst('Reconciliation', 'Balance check')
    : r.title;

IconData moneyIcon(MoneyRow r) {
  if (r.isTransfer) return Icons.swap_horiz;
  if (r.isCheck) return Icons.fact_check_outlined;
  if (r.type == ActivityType.cards) return Icons.credit_card_outlined;
  if (r.net > BigInt.zero) return Icons.south_west;
  if (r.net < BigInt.zero) return Icons.north_east;
  return Icons.remove;
}

IconData accountIcon(String kind) => switch (kind) {
  'Cash' => Icons.payments_outlined,
  'Mobile wallet' => Icons.phone_iphone,
  _ => Icons.account_balance_outlined,
};

/// What a balance check shows as its amount: it only compares.
const noMoneyMoved = 'No money moved';

/// One record in Activity: its newest version. [effect] is the version whose
/// postings count, which for a reversed record is the one it voided.
class MoneyRow {
  MoneyRow({
    required this.record,
    required this.effect,
    required this.label,
    required this.type,
    required this.change,
    required this.accounts,
    required this.categories,
    required this.waiting,
    required this.sequence,
    required this.accountLabel,
  });
  final LocalRevision record, effect;
  final String label;
  final ActivityType type;
  final RecordChange change;

  /// Every account the record touches, in posting order.
  final List<String> accounts;
  final List<String> categories;
  final bool waiting;
  final int sequence;
  final String accountLabel;

  String get id => record.id;
  String get title => recordTitle(effect);
  String get date => record.date;
  String get categoryLabel => categories.join(' / ');
  bool get reversed => change == RecordChange.reversed;
  bool get isTransfer => financeType(record) == 'transfer';
  bool get isCheck => financeType(record) == 'reconcile';

  /// The cash effect on [account], or across every account. Zero once
  /// reversed: the record no longer moves any money.
  BigInt cash([String? account]) => reversed
      ? BigInt.zero
      : sumMinor(
          record.postings
              .where(
                (p) =>
                    p.account != null &&
                    (account == null || p.account == account),
              )
              .map((p) => p.amount),
        );
  BigInt get net => cash();

  /// Movement in or out: an opening balance is where an account starts, not
  /// money that moved.
  BigInt flow([String? account]) =>
      record.kind == 'opening' ? BigInt.zero : cash(account);

  /// The amount as a row shows it. Money in and out are signed. A transfer
  /// is the amount moved, unless it's seen from one of its accounts. Records
  /// with no cash, and reversed ones, show their own amount.
  String shown(
    String Function(BigInt) amount, {
    required bool hidden,
    String? account,
  }) {
    if (isCheck) return noMoneyMoved;
    final value = cash(account);
    if (hidden) return amount(value);
    if (reversed || (isTransfer && account == null) || value == BigInt.zero) {
      return amount(record.amount);
    }
    return value > BigInt.zero ? '+${amount(value)}' : amount(value);
  }

  /// Lower-case text for search, without amounts while they're hidden.
  String searchText(bool hidden) {
    final v = record.values;
    return [
      title,
      label,
      accountLabel,
      categoryLabel,
      date,
      civilLabel(date),
      v['notes'],
      v['reference'],
      v['merchant'],
      v['sender'],
      v['sourceLabel'],
      if (!hidden) phpDecimal(record.amount.abs()),
    ].nonNulls.join(' ').toLowerCase();
  }
}

ActivityType _typeOf(LocalRevision r, BigInt net) {
  final type = financeType(r);
  if (type == 'transfer') return ActivityType.transfers;
  if (type.startsWith('card') || r.values['funding'] == 'card') {
    return ActivityType.cards;
  }
  if (type.startsWith('debt') || type == 'borrowing') {
    return ActivityType.debts;
  }
  if (const {'adjustment', 'opening', 'reconcile'}.contains(type)) {
    return ActivityType.adjustments;
  }
  return net > BigInt.zero ? ActivityType.moneyIn : ActivityType.moneyOut;
}

bool _isActivity(LocalRevision r) =>
    financeType(r) == 'reconcile' ||
    r.postings.any(
      (p) => p.account != null || p.ledger == 'expense' || p.ledger == 'income',
    );

/// Every money record, one row each, newest first: by date, then by when it
/// was logged. Replaced versions stay in Edit history; budgets, schedules
/// and other records that move no money aren't activity.
List<MoneyRow> moneyActivity(
  LocalSnapshot s,
  String Function(String?) categoryName, {
  bool Function(String id)? waiting,
}) {
  final newest = <String, (int, LocalRevision)>{};
  for (final (i, r) in s.revisions.indexed) {
    newest[r.actionId] = (i, r);
  }
  final byId = {for (final r in s.revisions) r.id: r};
  final names = {for (final a in s.accounts) a.id: a.name};
  final rows = <MoneyRow>[];
  for (final (sequence, r) in newest.values) {
    final reversed = r.change == 'reverse';
    final effect = reversed ? byId[r.previous] ?? r : r;
    if (!_isActivity(effect)) continue;
    final accounts = <String>{
      for (final p in effect.postings)
        if (p.account != null) p.account!,
      if (financeType(r) == 'reconcile') ?r.values['account'],
    }.toList();
    final net = sumMinor(
      effect.postings.where((p) => p.account != null).map((p) => p.amount),
    );
    final categories = <String>{
      for (final p in effect.postings)
        if (p.category != null) categoryName(p.category),
    }.toList();
    rows.add(
      MoneyRow(
        record: r,
        effect: effect,
        label: moneyLabel(r),
        type: _typeOf(r, net),
        change: reversed
            ? RecordChange.reversed
            : r.change == 'replace'
            ? RecordChange.corrected
            : RecordChange.none,
        accounts: accounts,
        categories: categories,
        waiting: waiting?.call(r.id) ?? false,
        sequence: sequence,
        accountLabel: accounts.map((a) => names[a] ?? 'Account').join(' → '),
      ),
    );
  }
  return rows..sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : b.sequence.compareTo(a.sequence);
  });
}

/// Money in and out of [accounts] from [from] to [to]: each record's cash
/// postings netted, so a transfer between them counts only its fee. Opening
/// balances aren't movement. Replaced and reversed versions don't count.
({BigInt moneyIn, BigInt moneyOut}) cashFlow(
  LocalSnapshot s,
  Iterable<String> accounts,
  String from,
  String to,
) {
  final ids = accounts.toSet();
  var moneyIn = BigInt.zero, moneyOut = BigInt.zero;
  for (final r in s.current) {
    if (r.kind == 'opening') continue;
    final net = sumMinor(
      r.postings
          .where(
            (p) =>
                ids.contains(p.account) &&
                p.date.compareTo(from) >= 0 &&
                p.date.compareTo(to) <= 0,
          )
          .map((p) => p.amount),
    );
    if (net > BigInt.zero) {
      moneyIn += net;
    } else {
      moneyOut -= net;
    }
  }
  return (moneyIn: moneyIn, moneyOut: moneyOut);
}

/// Available money: every account's balance through [through], archived ones
/// too, as `LocalSession.accepted` adds them up.
BigInt availableMoney(LocalSnapshot s, String through) =>
    sumMinor(s.accounts.map((a) => s.balance(a.id, through: through)));

/// The day before the first of [today]'s month.
String lastMonthEnd(String today) => addCivilDays(monthStart(today), -1);

/// The same days of last month: its first day, then [today]'s day of the
/// month, stopping at its last day.
(String, String) lastMonthSpan(String today) {
  final end = lastMonthEnd(today);
  final day = today.substring(8);
  return (
    monthStart(end),
    day.compareTo(end.substring(8)) <= 0 ? '${end.substring(0, 8)}$day' : end,
  );
}

/// The closing balance of [accounts] at each of the last [months] − 1 month
/// ends, then today.
List<(String, BigInt)> balanceByMonth(
  LocalSnapshot s,
  Iterable<String> accounts,
  String today, {
  int months = 12,
}) {
  final ids = accounts.toSet();
  final postings = s.current
      .expand((r) => r.postings)
      .where((p) => ids.contains(p.account))
      .toList();
  final ends = <String>[];
  var cursor = monthStart(today);
  for (var i = 1; i < months; i++) {
    final end = addCivilDays(cursor, -1);
    ends.insert(0, end);
    cursor = monthStart(end);
  }
  return [
    for (final d in [...ends, today])
      (
        d,
        sumMinor(
          postings.where((p) => p.date.compareTo(d) <= 0).map((p) => p.amount),
        ),
      ),
  ];
}

/// The newest balance check on [account].
LocalRevision? newestCheck(LocalSnapshot s, String account) {
  LocalRevision? found;
  for (final r in s.current) {
    if (financeType(r) != 'reconcile' || r.values['account'] != account) {
      continue;
    }
    if (found == null || r.date.compareTo(found.date) >= 0) found = r;
  }
  return found;
}

String? lastChecked(LocalSnapshot s, String account) =>
    newestCheck(s, account)?.date;

/// One account as "Where your money is" shows it.
class AccountRow {
  AccountRow(
    this.account,
    this.balance,
    this.basisPoints,
    this.change,
    this.checked,
  );
  final LocalAccount account;
  final BigInt balance;

  /// Its share of the positive total, in whole basis points. Null when it's
  /// at or below zero, which has no share.
  final int? basisPoints;

  /// Since the end of last month.
  final BigInt change;
  final String? checked;
}

/// Accounts, largest balance first. Shares are of the active accounts'
/// positive balances, so a below-zero account never makes them add past 100%.
List<AccountRow> accountRows(
  LocalSnapshot s,
  String today, {
  bool archived = false,
}) {
  final before = lastMonthEnd(today);
  final active = s.accounts.where((a) => !a.archived).toList();
  final total = sumMinor(
    active
        .map((a) => s.balance(a.id, through: today))
        .where((b) => b > BigInt.zero),
  );
  final rows = [
    for (final a in s.accounts.where((a) => a.archived == archived))
      () {
        final balance = s.balance(a.id, through: today);
        return AccountRow(
          a,
          balance,
          !archived && balance > BigInt.zero
              ? shareBasisPoints(balance, total)
              : null,
          balance - s.balance(a.id, through: before),
          lastChecked(s, a.id),
        );
      }(),
  ];
  return rows..sort((a, b) => b.balance.compareTo(a.balance));
}

/// Where a balance check stands.
enum CheckState {
  /// Salapiya matched what you counted.
  matched('Matched'),

  /// There's a difference nothing has resolved yet.
  difference('Difference to resolve'),

  /// An adjustment resolved the difference.
  adjusted('Adjusted'),

  /// Records dated on or before it changed since, so it no longer applies.
  changed('Records changed since');

  const CheckState(this.label);
  final String label;
}

/// As `LocalFinancialController.comparisonStatus`, plus whether an adjustment
/// already resolved it.
CheckState balanceCheckState(LocalSnapshot s, LocalRevision check) {
  if (s.current.any((r) => r.kind == 'adjustment' && r.source == check.id)) {
    return CheckState.adjusted;
  }
  final account = check.values['account']!;
  final now = s.balance(account, through: check.date);
  final count = s.current
      .expand((r) => r.postings)
      .where((p) => p.account == account && p.date.compareTo(check.date) <= 0)
      .length;
  if ('$now' != check.values['calculated'] ||
      '$count' != check.values['sourceCount']) {
    return CheckState.changed;
  }
  return check.amount == BigInt.zero
      ? CheckState.matched
      : CheckState.difference;
}

/// Why Money needs the user.
enum MoneyNeed { belowZero, balanceCheck, drafts }

typedef MoneyTask = ({
  MoneyNeed need,
  String title,
  String subtitle,
  String id,
});

/// What needs the user: accounts below zero, each account's newest balance
/// check if it's still open, and saved drafts.
List<MoneyTask> moneyTasks(LocalSnapshot s, String today, {int drafts = 0}) => [
  for (final a in s.accounts.where((a) => !a.archived))
    if (s.balance(a.id, through: today) < BigInt.zero)
      (
        need: MoneyNeed.belowZero,
        title: '${a.name} is below zero',
        subtitle: 'Check what you logged, or log what’s missing',
        id: a.id,
      ),
  for (final a in s.accounts.where((a) => !a.archived))
    if (newestCheck(s, a.id) case final check?)
      if (balanceCheckState(s, check) case final state
          when state == CheckState.difference || state == CheckState.changed)
        (
          need: MoneyNeed.balanceCheck,
          title: '${a.name} balance check',
          subtitle: state.label,
          id: check.id,
        ),
  if (drafts > 0)
    (
      need: MoneyNeed.drafts,
      title: drafts == 1 ? '1 saved draft' : '$drafts saved drafts',
      subtitle: 'Not in your records yet',
      id: 'drafts',
    ),
];

/// The period Activity lists.
enum ActivityPeriod {
  thisMonth('This month'),
  lastMonth('Last month'),
  last90('Last 90 days'),
  all('All dates'),
  custom('Custom');

  const ActivityPeriod(this.label);
  final String label;
}

/// What Activity is showing. Search looks through every date, whatever the
/// period says.
class ActivityFilter {
  const ActivityFilter({
    this.query = '',
    this.type = ActivityType.all,
    this.account,
    this.category,
    this.period = ActivityPeriod.thisMonth,
    this.from,
    this.to,
  });
  final String query;
  final ActivityType type;
  final String? account, category;
  final ActivityPeriod period;

  /// A custom period; either end may be open.
  final String? from, to;

  bool get searching => query.trim().isNotEmpty;

  /// Counted on the Filters button: what the button's dialog set.
  int get filters =>
      (account == null ? 0 : 1) +
      (category == null ? 0 : 1) +
      (period == ActivityPeriod.custom ? 1 : 0);

  bool get active => searching || type != ActivityType.all || filters > 0;

  ActivityPeriod get shownPeriod => searching ? ActivityPeriod.all : period;

  /// The dates listed. "This month" and "Last 90 days" have no end, so
  /// records dated later stay in view.
  (String?, String?) range(String today) => switch (shownPeriod) {
    ActivityPeriod.thisMonth => (monthStart(today), null),
    ActivityPeriod.lastMonth => (
      monthStart(lastMonthEnd(today)),
      lastMonthEnd(today),
    ),
    ActivityPeriod.last90 => (addCivilDays(today, -89), null),
    ActivityPeriod.all => (null, null),
    ActivityPeriod.custom => (from, to),
  };

  bool shows(MoneyRow r, String today, {bool hidden = false}) {
    final (start, end) = range(today);
    if (start != null && r.date.compareTo(start) < 0) return false;
    if (end != null && r.date.compareTo(end) > 0) return false;
    if (account != null && !r.accounts.contains(account)) return false;
    if (category != null && !r.categories.contains(category)) return false;
    final matches = switch (type) {
      ActivityType.all => true,
      ActivityType.moneyOut => r.flow(account) < BigInt.zero,
      ActivityType.moneyIn => r.flow(account) > BigInt.zero,
      _ => r.type == type,
    };
    if (!matches) return false;
    if (!searching) return true;
    final text = r.searchText(hidden);
    return query
        .toLowerCase()
        .replaceAll(',', '')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .every(text.contains);
  }

  ActivityFilter copyWith({
    String? query,
    ActivityType? type,
    ActivityPeriod? period,
  }) => ActivityFilter(
    query: query ?? this.query,
    type: type ?? this.type,
    account: account,
    category: category,
    period: period ?? this.period,
    from: from,
    to: to,
  );
}

/// Totals of what a list shows. Records dated later and reversed ones aren't
/// in any balance, so they aren't in these; seen from one [account], a
/// transfer counts for that account.
({BigInt moneyIn, BigInt moneyOut}) listedTotals(
  Iterable<MoneyRow> rows,
  String today, {
  String? account,
}) {
  var moneyIn = BigInt.zero, moneyOut = BigInt.zero;
  for (final r in rows) {
    if (r.date.compareTo(today) > 0) continue;
    final net = r.flow(account);
    if (net > BigInt.zero) {
      moneyIn += net;
    } else {
      moneyOut -= net;
    }
  }
  return (moneyIn: moneyIn, moneyOut: moneyOut);
}

/// A day header in a dated list.
String dayLabel(String date, String today) => date.compareTo(today) > 0
    ? 'Later · not in your balance yet'
    : date == today
    ? 'Today · ${civilLabel(date)}'
    : date == addCivilDays(today, -1)
    ? 'Yesterday · ${civilLabel(date)}'
    : civilLabel(date);

/// A list's period as a heading: "October 2026", or its span.
String periodHeading(String from, String to) {
  final start = DateTime.parse(from), end = DateTime.parse(to);
  final wholeMonth = from == monthStart(from) && to == monthEnd(from);
  return wholeMonth
      ? '${_month(start.month)} ${start.year}'
      : start.year == end.year
      ? overviewSpan(from, to)
      : '${DateField.format(start)} – ${DateField.format(end)}';
}

String _month(int month) => const [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
][month - 1];

/// The shareable list: every item of a period, oldest first, with its
/// totals. On one [account] it's a statement, with the balance after each
/// row, so its starting and closing balances are exact.
class Statement {
  Statement._(
    this.from,
    this.to,
    this.account,
    this.rows,
    this.balances,
    this.starting,
    this.closing,
  );

  factory Statement.of(
    LocalSnapshot s,
    Iterable<MoneyRow> rows,
    String from,
    String to, {
    String? account,
  }) {
    // Reversed records move nothing, and later ones aren't in a balance.
    final listed =
        [
          for (final r in rows)
            if (!r.reversed &&
                !r.isCheck &&
                r.date.compareTo(from) >= 0 &&
                r.date.compareTo(to) <= 0 &&
                (account == null || r.cash(account) != BigInt.zero))
              r,
        ]..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate != 0 ? byDate : a.sequence.compareTo(b.sequence);
        });
    if (account == null) {
      return Statement._(from, to, null, listed, const [], null, null);
    }
    final starting = s.balance(account, through: addCivilDays(from, -1));
    var running = starting;
    final balances = <BigInt>[];
    for (final r in listed) {
      running += sumMinor(
        r.record.postings
            .where(
              (p) =>
                  p.account == account &&
                  p.date.compareTo(from) >= 0 &&
                  p.date.compareTo(to) <= 0,
            )
            .map((p) => p.amount),
      );
      balances.add(running);
    }
    return Statement._(from, to, account, listed, balances, starting, running);
  }

  final String from, to;
  final String? account;
  final List<MoneyRow> rows;

  /// The balance after each row; empty without an [account].
  final List<BigInt> balances;
  final BigInt? starting, closing;
}

/// What a record's page can offer.
class RecordActions {
  const RecordActions({
    this.correct = false,
    this.reverse = false,
    this.refund = false,
    this.adjust = false,
    this.checkAgain = false,
    this.blocked,
    this.shared = false,
    this.superseded,
  });
  final bool correct, reverse, refund, adjust, checkAgain;

  /// Why Correct and Reverse are off, when they are.
  final String? blocked;

  /// Linked to Shared Expenses, so it's changed there.
  final bool shared;

  /// The current version's id, when this is an earlier one.
  final String? superseded;

  bool get any => correct || reverse || refund || adjust || checkAgain;
}

/// Money records are corrected with Money's forms; others have their own
/// workflow. Reads what `planLocal` will insist on, so nothing fails at
/// Review.
RecordActions recordActions(LocalSnapshot s, LocalRevision r) {
  final current = s.current.any((x) => x.id == r.id);
  if (!current) {
    final latest = s.revisions.lastWhere((x) => x.actionId == r.actionId);
    return RecordActions(
      superseded: latest.id == r.id || latest.change == 'reverse'
          ? null
          : latest.id,
    );
  }
  if (r.values.containsKey('sharedGroup')) {
    return const RecordActions(shared: true);
  }
  final type = financeType(r);
  if (type == 'reconcile') {
    final state = balanceCheckState(s, r);
    return RecordActions(
      adjust: state == CheckState.difference,
      checkAgain: state == CheckState.changed,
    );
  }
  if (nativeFinanceCommands.contains(type)) {
    // The rules keep these to the item they belong to.
    const owned = {
      'reservation',
      'savingsReallocation',
      'recurrenceGenerate',
      'occurrenceOverride',
      'recurrenceLink',
      'recurrenceUnlink',
    };
    if (owned.contains(type)) {
      return const RecordActions(
        blocked:
            'This is changed from the goal or recurring item it belongs to.',
      );
    }
    final depended = s.current.any(
      (x) =>
          x.id != r.id &&
          financeType(x) != 'financialFile' &&
          financeDependsOn(x, r),
    );
    // A schedule or recurring item can be replaced with records on it, but
    // only a budget, goal or item can't be reversed: they're archived.
    final replaceable = const {'debtSchedule', 'recurrence'}.contains(type);
    final permanent = const {
      'budget',
      'savingsGoal',
      'recurrence',
    }.contains(type);
    return RecordActions(
      correct: !depended || replaceable,
      reverse: !depended && !permanent,
      blocked: depended && !replaceable
          ? 'Other records depend on this one. Reverse those first.'
          : null,
    );
  }
  const money = {
    'expense',
    'income',
    'transfer',
    'refund',
    'adjustment',
    'opening',
  };
  if (!money.contains(type)) return const RecordActions();
  final dependent = s.current.any(
    (x) =>
        x.source != null &&
        financeType(x) != 'financialFile' &&
        s.revision(x.source!).actionId == r.actionId,
  );
  final refundable =
      const {'expense', 'transfer'}.contains(type) &&
      r.postings.any((p) => p.ledger == 'expense');
  return RecordActions(
    correct: true,
    reverse: true,
    refund: refundable,
    blocked: dependent
        ? 'It has a refund or an adjustment. Reverse that first.'
        : null,
  );
}

/// One plain line of what a record did.
typedef RecordEffect = ({
  String label,
  String? detail,
  BigInt amount,

  /// Money moving in or out of an account, shown with its sign.
  bool cash,
});

/// Each posting in words, signed as the person sees it: money leaving an
/// account is negative, spending and income are positive.
List<RecordEffect> recordEffects(
  LocalSnapshot s,
  LocalRevision r,
  String Function(String?) categoryName,
) {
  const words = {
    'cash': 'Cash movement',
    'expense': 'Spending',
    'income': 'Income',
    'card_liability': 'Card debt',
    'debt_liability': 'What you owe',
    'receivable': 'Owed to you',
    'shared_receivable': 'Owed to you in a group',
    'shared_payable': 'You owe in a group',
    'payable': 'You owe',
    'private_clearing': 'Waiting to be linked',
    'equity': 'Opening balance',
  };
  const credits = {
    'income',
    'card_liability',
    'debt_liability',
    'payable',
    'shared_payable',
    'equity',
  };
  final names = {for (final a in s.accounts) a.id: a.name};
  return [
    for (final p in r.postings)
      (
        label: p.account != null
            ? names[p.account] ?? 'Account'
            : words[p.ledger] ?? p.ledger.replaceAll('_', ' '),
        detail: p.category != null ? categoryName(p.category) : null,
        amount: credits.contains(p.ledger) ? -p.amount : p.amount,
        cash: p.account != null,
      ),
  ];
}

/// Opens a records form: a real one, or the demo's placeholder.
typedef MoneyForm = void Function(
  String operation,
  String title, {
  Map<String, String> initial,
  LocalRevision? replacing,
  Map<String, String> overrides,
});

/// Everything the Money screens can do; the local and demo sources fill it.
class MoneyActions {
  const MoneyActions({
    required this.logExpense,
    required this.logIncome,
    required this.logTransfer,
    required this.addAccount,
    required this.addCategory,
    required this.checkBalance,
    required this.adjustBalance,
    required this.archive,
    required this.openAccount,
    required this.openRecord,
    required this.openCategories,
    required this.openDrafts,
    required this.correct,
    required this.reverse,
    required this.refund,
    required this.adjustToMatch,
    required this.form,
    required this.openItem,
    required this.openForecast,
    required this.openCardDues,
    required this.exportCsv,
    required this.importFile,
    required this.continueImport,
    required this.openImport,
    required this.attachFile,
    required this.openFile,
  });
  final void Function(String? account) logExpense, logIncome, logTransfer;
  final void Function() addAccount, addCategory, openCategories, openDrafts;
  final void Function(String account) checkBalance, adjustBalance, archive;
  final void Function(String account) openAccount;

  /// Opens one record by its revision id.
  final void Function(String id) openRecord;
  final void Function(LocalRevision record) correct, reverse, refund;
  final void Function(LocalRevision check) adjustToMatch;
  final MoneyForm form;

  /// Opens a card, statement, plan, budget, goal or recurring item on its own
  /// page, by revision or action id; anything else on the record page.
  final void Function(String id) openItem;
  final void Function() openForecast;

  /// Every open statement and installment.
  final void Function() openCardDues;

  /// Saves a report's postings: [from] through [to], narrowed by ids.
  final void Function(String from, String to, String? account, String? category)
  exportCsv;

  /// Picks a file and opens its review. These end when the page closes.
  final Future<void> Function() importFile;

  /// Picks up an import: [batch] from the records, or the saved draft.
  final Future<void> Function(String? batch) continueImport;

  /// One import's page.
  final Future<void> Function(String batch) openImport;
  final Future<void> Function() attachFile;

  /// One file's page.
  final Future<void> Function(String id) openFile;
}

/// Everything the Money screens read. A real profile fills it from its
/// session (`localMoneySource`); the demo build from its sample profile
/// (`demoMoneySource`).
class MoneySource {
  const MoneySource({
    required this.today,
    required this.snapshot,
    required this.complete,
    required this.hidden,
    required this.amount,
    required this.categoryName,
    required this.actions,
    this.waiting,
    this.cards,
    this.pending = false,
    this.pendingCount = 0,
    this.needsReview = false,
    this.syncLabel = '',
    this.onReview,
    this.draftCount,
    this.importDraft,
    this.files,
  });
  final String today;

  /// Money's records, including waiting work, as in Debts.
  final LocalSnapshot snapshot;
  final bool complete, hidden, pending, needsReview;
  final int pendingCount;
  final String syncLabel;
  final String Function(BigInt) amount;
  final String Function(String?) categoryName;
  final MoneyActions actions;

  /// Card debt and available credit, when the profile has a card.
  final (BigInt, BigInt)? cards;
  final bool Function(String id)? waiting;
  final void Function()? onReview;

  /// Reads how many drafts are saved.
  final Future<int> Function()? draftCount;

  /// Reads the file chosen for import and not finished, if any.
  final Future<Map<String, String>?> Function()? importDraft;

  /// Null with no store to read, as on a page opened outside Money.
  final FileAccess? files;
}
