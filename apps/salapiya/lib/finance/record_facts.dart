import '../app/overview_cards.dart' show civilLabel;
import '../local/finance_domain.dart';
import '../p0/exact_money.dart';
import 'files_data.dart';
import 'money_data.dart';
import 'planning_data.dart';

/// What a Cards, Planning or Files record holds, in plain labels, with ids
/// resolved to names. Empty for any other record, whose page lists its own.
/// Amounts go through [amount], so hidden amounts stay hidden.
List<(String, String?)> recordFacts(
  LocalSnapshot s,
  LocalRevision r,
  String Function(BigInt) amount,
  String Function(String?) categoryName,
) {
  final v = r.values;
  String? text(String key) =>
      (v[key] ?? '').trim().isEmpty ? null : v[key]!.trim();
  String? date(String key) => text(key) == null ? null : civilLabel(text(key)!);
  String? money(String key) =>
      text(key) == null ? null : amount(parsePhp(text(key)!));
  String? name(String key) {
    final id = text(key);
    if (id == null) return null;
    final found = s.revisions
        .where((x) => x.id == id || x.actionId == id)
        .lastOrNull;
    return found == null ? null : recordTitle(found);
  }

  String? yes(String key) => text(key) == 'true' ? 'Yes' : 'No';
  String? account(String key) =>
      s.accounts.where((a) => a.id == text(key)).firstOrNull?.name;
  String? status() => switch (text('status')) {
    'active' => 'Active',
    'archived' => 'Archived',
    'completed' => 'Completed',
    'suspended' => 'Suspended',
    final other => other,
  };
  final card = ('Card', name('card'));
  return switch (financeType(r)) {
    'creditCard' => [
      ('Issuer', text('issuer')),
      ('Credit limit', money('limit')),
    ],
    'cardPurchase' || 'cardFee' || 'cardInterest' => [
      card,
      ('Date it posted', date('postingDate')),
      ('Pending charge', name('authorization')),
    ],
    'cardRefund' => [
      card,
      ('Original purchase', name('purchase')),
      ('Why', text('reason')),
    ],
    'cardAuthorization' => [card],
    'statement' => [
      card,
      (
        'Period',
        text('start') == null || text('end') == null
            ? null
            : periodHeading(text('start')!, text('end')!),
      ),
      ('Statement date', date('issued')),
      ('Due date', date('due')),
      ('Minimum due', money('minimum')),
      ('Confirmed', yes('verified')),
    ],
    'statementLink' => [
      card,
      ('Statement', name('statement')),
      ('Activity', name('activity')),
      ('Confirmed', yes('verified')),
    ],
    'cardAllocation' => [
      card,
      ('Statement', name('statement')),
      ('Payment', name('payment')),
      ('Confirmed', yes('verified')),
    ],
    'installment' => [
      card,
      ('Purchase', name('purchase')),
      (
        'Payments',
        text('schedule') == null
            ? null
            : '${financeSchedule(text('schedule')!).length}',
      ),
      ('Principal', money('principal')),
      ('Interest', money('interest')),
      ('Fee', money('fee')),
      ('Confirmed', yes('verified')),
    ],
    'installmentApplication' => [
      card,
      ('Plan', name('plan')),
      ('Payment', name('payment')),
      ('Confirmed', yes('verified')),
    ],
    'budget' => [
      ('Category', categoryName(v['category'])),
      ('Period', budgetPeriodLabel(r)),
      ('What counts', text('basis') == 'gross' ? 'Gross' : 'Net'),
      ('Status', status()),
    ],
    'savingsGoal' => [
      ('Target date', date('targetDate')),
      ('Status', status()),
    ],
    'reservation' => [
      ('Goal', name('goal')),
      ('Account', account('account')),
      (
        'Change',
        text('delta') == null ? null : amount(BigInt.parse(text('delta')!)),
      ),
    ],
    'savingsReallocation' => [
      ('From goal', name('fromGoal')),
      ('From account', account('fromAccount')),
      ('To goal', name('goal')),
      ('To account', account('account')),
    ],
    'recurrence' => [
      ('Item type', recurringKindLabel(v['recurringKind'])),
      ('How often', recurringLabel(r)),
      ('Starts', date('start')),
      ('Ends', date('end')),
      ('How many times', text('count')),
      ('Time zone', text('timezone')),
      ('Account', account('account')),
      ('Status', status()),
    ],
    'recurrenceGenerate' => [
      ('Item', name('rule')),
      ('From', date('from')),
      ('Through', date('through')),
    ],
    'occurrenceOverride' => [
      ('Item', name('rule')),
      ('Original date', date('logicalDate')),
      ('New due date', date('due')),
      ('What happened', dateStateLabel(v['state'] ?? '')),
      ('Why', text('reason')),
    ],
    'recurrenceLink' => [
      ('Item', name('rule')),
      ('Original date', date('logicalDate')),
      ('Record', name('actual')),
    ],
    'recurrenceUnlink' => [('Link', name('link')), ('Why', text('reason'))],
    'financialFile' => [
      ('Attached to', name('sourceRevision')),
      ('File type', fileType(v['mime'])),
      ('Size', fileSize(int.tryParse(v['size'] ?? '') ?? 0)),
      ('Where', 'Stays on this device. Only its details sync.'),
    ],
    'fileDetach' => [('File', name('file')), ('Why', text('reason'))],
    _ => const [],
  };
}
