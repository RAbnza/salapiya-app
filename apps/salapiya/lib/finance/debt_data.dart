import '../app/overview_data.dart';
import '../local/finance_domain.dart';
import '../p0/exact_money.dart';

/// Display-only derivations for Debts (DESIGN_SYSTEM §8, Chat 7). They group,
/// count and add up exact values the domain already returns; statuses come
/// from `debtDueStatus`, and no money rule lives here. Dates are civil
/// `YYYY-MM-DD` strings, as `civilToday()` gives them.

/// The tabs of the Debts section, in order.
enum DebtsTab {
  summary('Summary'),
  schedule('Schedule'),
  payments('Payments'),
  history('History');

  const DebtsTab(this.label);
  final String label;

  static DebtsTab of(String? label) => values.firstWhere(
    (t) => t.label == label,
    orElse: () => DebtsTab.summary,
  );
}

/// One unpaid scheduled payment of a debt.
class OpenPayment {
  OpenPayment(this.debt, this.row, this.left, String today)
    : status = debtDueStatus(row.date, today),
      days = civilDaysBetween(today, row.date);
  final DebtProgress debt;
  final FinanceScheduleRow row;
  final BigInt left;
  final DebtDueStatus status;

  /// Calendar days from today; negative when overdue.
  final int days;
  String get date => row.date;
}

/// Every unpaid scheduled payment across [debts], earliest first.
List<OpenPayment> openPayments(List<DebtProgress> debts, String today) =>
    [
      for (final d in debts)
        for (final (row, left) in d.due.open) OpenPayment(d, row, left, today),
    ]..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0
          ? byDate
          : a.debt.debt.title.compareTo(b.debt.debt.title);
    });

/// What the Summary tiles say (A1–A3).
class DebtsSummary {
  DebtsSummary(this.debts, this.today) : payments = openPayments(debts, today);
  final List<DebtProgress> debts;
  final String today;
  final List<OpenPayment> payments;

  BigInt get owed => sumMinor(debts.map((d) => d.outstanding));

  List<OpenPayment> get overdue => payments.where((p) => p.days < 0).toList();
  BigInt get overdueTotal => sumMinor(overdue.map((p) => p.left));

  /// Days past due of the oldest overdue payment; 0 with none.
  int get oldestOverdueDays => overdue.isEmpty ? 0 : -overdue.first.days;

  /// Everything from today on. Overdue rows are never "next".
  List<OpenPayment> get upcoming => payments.where((p) => p.days >= 0).toList();

  /// The payments on the earliest upcoming date.
  List<OpenPayment> get next {
    final rows = upcoming;
    return rows.isEmpty
        ? const []
        : rows.where((p) => p.date == rows.first.date).toList();
  }

  BigInt get nextTotal => sumMinor(next.map((p) => p.left));

  /// From today to the end of the calendar month.
  List<OpenPayment> get thisMonth {
    final end = monthEnd(today);
    return upcoming.where((p) => p.date.compareTo(end) <= 0).toList();
  }

  BigInt get thisMonthTotal => sumMinor(thisMonth.map((p) => p.left));
}

/// [count] calendar months from the one holding [from], as their first days.
List<String> calendarMonths(String from, int count) {
  final months = <String>[];
  var cursor = monthStart(from);
  for (var i = 0; i < count; i++) {
    months.add(cursor);
    cursor = addCivilDays(monthEnd(cursor), 1);
  }
  return months;
}

/// A4: what is due in this month and the next five. Overdue rows stay out;
/// the current month starts today.
List<(String, BigInt)> dueByMonth(
  Iterable<FinancialReminderSource> sources,
  String today, {
  int months = 6,
}) => [
  for (final month in calendarMonths(today, months))
    (
      month,
      sumMinor(
        sources
            .where(
              (r) =>
                  r.date.compareTo(today) >= 0 && monthStart(r.date) == month,
            )
            .map((r) => r.amount),
      ),
    ),
];

/// The last day of the [count]-month window starting at [today]'s month.
String dueWindowEnd(String today, {int count = 6}) =>
    monthEnd(calendarMonths(today, count).last);

/// How much of a logged payment is explained, in everyday words.
enum PaymentBreakdown {
  reducesDebt('Lowers what you owe'),
  known('Breakdown known'),
  unknown('No breakdown yet');

  const PaymentBreakdown(this.label);
  final String label;
}

/// A5: one logged payment, as the Payments tables show it.
class DebtPaymentRow {
  DebtPaymentRow(this.record, this.debtTitle, this.paidFrom, this.left);
  final LocalRevision record;
  final String debtTitle, paidFrom;

  /// What is still without a breakdown.
  final BigInt left;

  String get date => record.date;
  BigInt get amount => record.amount;
  List<String> get appliedTo =>
      debtAllocations(record.values['allocations'] ?? '').keys.toList();
  PaymentBreakdown get breakdown => left > BigInt.zero
      ? PaymentBreakdown.unknown
      : record.values['certainty'] == 'confirmed_total'
      ? PaymentBreakdown.reducesDebt
      : PaymentBreakdown.known;
}

BigInt _clearingLeft(LocalSnapshot s, LocalRevision payment) =>
    parsePhp(
      (payment.values['clearing'] ?? '').isEmpty
          ? '0.00'
          : payment.values['clearing']!,
    ) -
    sumMinor(
      s.current
          .where(
            (r) =>
                financeType(r) == 'debtClassification' &&
                r.values['payment'] == payment.id,
          )
          .map((r) => r.amount),
    );

/// Logged payments, newest first; all of them, or one debt's by action id.
List<DebtPaymentRow> debtPaymentRows(LocalSnapshot s, {String? debt}) {
  final rows = [
    for (final r in s.current)
      if (financeType(r) == 'debtPayment' &&
          (debt == null || r.values['debt'] == debt))
        DebtPaymentRow(
          r,
          debtRecord(s, r.values['debt'])?.title ?? r.title,
          s.accounts
                  .where((a) => a.id == r.values['account'])
                  .firstOrNull
                  ?.name ??
              'Not recorded',
          _clearingLeft(s, r),
        ),
  ];
  return rows..sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : b.record.number.compareTo(a.record.number);
  });
}

/// A5: what was logged in each of the last [months] calendar months, through
/// [today], oldest first: payments plus early payoffs.
List<(String, BigInt)> paidByMonth(
  LocalSnapshot s,
  String today, {
  int months = 6,
}) {
  final list = <String>[monthStart(today)];
  for (var i = 1; i < months; i++) {
    list.insert(0, monthStart(addCivilDays(list.first, -1)));
  }
  return [
    for (final month in list)
      (
        month,
        sumMinor(
          s.current
              .where(
                (r) =>
                    ['debtPayment', 'debtPayoff'].contains(financeType(r)) &&
                    r.date.compareTo(today) <= 0 &&
                    monthStart(r.date) == month,
              )
              .map((r) => r.amount),
        ),
      ),
  ];
}

/// A5: how far what you owe went down from [from] to [to] through payments,
/// breakdowns and payoffs. Waivers and lender charges aren't counted.
BigInt paidDownBetween(LocalSnapshot s, String from, String to) => sumMinor(
  s.current
      .where(
        (r) => [
          'debtPayment',
          'debtClassification',
          'debtPayoff',
        ].contains(financeType(r)),
      )
      .expand((r) => r.postings)
      .where(
        (p) =>
            p.ledger == 'debt_liability' &&
            p.amount > BigInt.zero &&
            p.date.compareTo(from) >= 0 &&
            p.date.compareTo(to) <= 0,
      )
      .map((p) => p.amount),
);

/// One row of a debt's payments table (A6).
class InstallmentRow {
  InstallmentRow(this.row, this.paid, this.cancelled, String today)
    : days = civilDaysBetween(today, row.date),
      status = debtDueStatus(row.date, today);
  final FinanceScheduleRow row;
  final BigInt paid;
  final int days;
  final DebtDueStatus status;

  /// Closed by a payoff before this payment was covered.
  final bool cancelled;

  BigInt get left => row.amount - paid;
  bool get settled => left <= BigInt.zero;
  bool get open => !settled && !cancelled;
  String get statusLabel => settled
      ? 'Paid'
      : cancelled
      ? 'Cancelled by payoff'
      : status.label;
}

List<InstallmentRow> installmentRows(
  LocalSnapshot s,
  DebtProgress d,
  String today,
) => [
  for (final row in d.rows)
    InstallmentRow(
      row,
      debtInstallmentPaid(s, d.due.schedule!, row, today),
      d.closed,
      today,
    ),
];

/// A8: what a debt record is, in everyday words.
String recordLabel(LocalRevision r) {
  final type = financeType(r);
  final base = switch (type) {
    'debtImport' => 'Debt added',
    'borrowing' => 'New loan logged',
    'debtPayment' => 'Payment logged',
    'debtClassification' => 'Payment broken down',
    'debtSchedule' => 'Payment schedule set',
    'debtPayoff' => 'Early payoff logged',
    'debtAdjustment' => 'Lender charge or waiver logged',
    _ => 'Record',
  };
  return switch (r.change) {
    'reverse' => '$base, then reversed',
    'replace' when type == 'debtSchedule' => 'Payment schedule edited',
    'replace' => '$base, then corrected',
    _ => base,
  };
}

/// Every revision of every debt record, newest first, or those of one debt.
List<LocalRevision> debtHistory(LocalSnapshot s, {String? debt}) => s
    .revisions
    .reversed
    .where(
      (r) =>
          nativeDebtCommands.contains(financeType(r)) &&
          (debt == null || r.values['debt'] == debt || r.actionId == debt),
    )
    .toList();

/// The current records of one debt other than the debt and its schedule:
/// payments, breakdowns, lender charges and the payoff, newest first.
List<LocalRevision> debtActivity(LocalSnapshot s, String debt) {
  final list = [
    for (final r in s.current)
      if (r.values['debt'] == debt &&
          const {
            'debtPayment',
            'debtClassification',
            'debtAdjustment',
            'debtPayoff',
          }.contains(financeType(r)))
        r,
  ];
  return list..sort((a, b) => b.date.compareTo(a.date));
}

/// Why a debt needs the user, for Needs your input.
enum DebtNeed { schedule, confirmAmount, breakdown }

typedef DebtTask = ({DebtProgress debt, DebtNeed need});

/// What needs the user: a schedule to set, a varied amount to confirm before
/// it falls due, and payments to break down.
List<DebtTask> debtTasks(List<DebtProgress> debts) => [
  for (final d in debts) ...[
    if (!d.scheduled && !d.paidOff) (debt: d, need: DebtNeed.schedule),
    if (d.due.amountsVary &&
        const {
          DebtDueStatus.overdue,
          DebtDueStatus.dueToday,
          DebtDueStatus.dueSoon,
        }.contains(d.due.status))
      (debt: d, need: DebtNeed.confirmAmount),
    if (d.clearing > BigInt.zero) (debt: d, need: DebtNeed.breakdown),
  ],
];

/// The filter on Your debts.
enum DebtFilter {
  all('All'),
  overdue('Overdue'),
  upcoming('Upcoming'),
  noSchedule('No schedule'),
  paidOff('Paid off');

  const DebtFilter(this.label);
  final String label;

  bool shows(DebtProgress d) => switch (this) {
    DebtFilter.all => true,
    DebtFilter.overdue => d.rank == 0,
    DebtFilter.upcoming => d.rank == 1 || d.rank == 2,
    DebtFilter.noSchedule => d.rank == 3 || d.rank == 4,
    DebtFilter.paidOff => d.paidOff,
  };
}

/// What "Log payment" fills in. Nothing is allocated until the user reviews
/// and saves it: this only proposes [payment], or the next open one.
Map<String, String> debtPaymentInitial(DebtProgress d, [OpenPayment? payment]) {
  final row = payment?.row ?? d.due.next?.$1;
  final left = payment?.left ?? d.due.next?.$2;
  return {
    'debt': d.debt.id,
    'name': 'Payment · ${d.debt.title}',
    if (row != null && left != null) ...{
      'scheduleSource': d.due.schedule!.id,
      'allocations': '${row.id},${phpDecimal(left)}',
      'amount': phpDecimal(left),
      'certainty': 'confirmed_total',
      'reduction': phpDecimal(left),
    },
  };
}

/// Everything the Debts screens can do; the local and demo sources fill it.
class DebtActions {
  const DebtActions({
    required this.logPayment,
    required this.addDebt,
    required this.newLoan,
    required this.schedule,
    required this.updateAmounts,
    required this.breakDown,
    required this.lenderCharge,
    required this.earlyPayoff,
    required this.openDebt,
    required this.openRecord,
  });
  final void Function(DebtProgress? debt, OpenPayment? payment) logPayment;
  final void Function() addDebt, newLoan;
  final void Function(DebtProgress debt) schedule,
      updateAmounts,
      lenderCharge,
      earlyPayoff,
      openDebt;

  /// Opens the breakdown form, on one payment when [paymentId] is given.
  final void Function(DebtProgress debt, String? paymentId) breakDown;

  /// Opens one record by its revision id.
  final void Function(String id) openRecord;
}

/// Everything the Debts screens read. A real profile fills it from its
/// session (`localDebtsSource`); the demo build from its sample profile
/// (`demoDebtsSource`).
class DebtsSource {
  const DebtsSource({
    required this.today,
    required this.snapshot,
    required this.complete,
    required this.hidden,
    required this.amount,
    required this.actions,
    this.pending = false,
    this.pendingCount = 0,
    this.needsReview = false,
    this.syncLabel = '',
    this.onReview,
  });
  final String today;

  /// The Debts screen's records, including waiting work (§2 Snapshots).
  final LocalSnapshot snapshot;
  final bool complete, hidden, pending, needsReview;
  final int pendingCount;
  final String syncLabel;
  final String Function(BigInt) amount;
  final DebtActions actions;
  final void Function()? onReview;
}
