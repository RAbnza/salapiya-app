part of '../local/finance_domain.dart';

const nativeRecurrenceCommands = {
  'recurrence',
  'recurrenceGenerate',
  'occurrenceOverride',
  'recurrenceLink',
  'recurrenceUnlink',
};
bool _zonesReady = false;
tz.Location financeZone(String name) {
  if (!_zonesReady) {
    tzdata.initializeTimeZones();
    _zonesReady = true;
  }
  try {
    return tz.getLocation(name);
  } catch (_) {
    reject('Choose a time zone from the list.');
  }
}

String financeZoneToday(String name) =>
    tz.TZDateTime.now(financeZone(name)).toIso8601String().substring(0, 10);
String occurrenceIdentity(LocalRevision rule, String logical) {
  final digest = crypto.sha256
      .convert(
        utf8.encode(
          'salapiya-recurring-1:${rule.actionId}:${rule.number}:$logical',
        ),
      )
      .toString();
  return '${digest.substring(0, 8)}-${digest.substring(8, 12)}-5${digest.substring(13, 16)}-a${digest.substring(17, 20)}-${digest.substring(20, 32)}';
}

List<String> recurringDates(
  Map<String, String> v,
  String from,
  String through,
) {
  planningDate(from);
  planningDate(through);
  final start = DateTime.parse('${planningDate(v['start'] ?? '')}T00:00:00Z');
  final to = DateTime.parse('${through}T00:00:00Z'),
      windowStart = DateTime.parse('${from}T00:00:00Z');
  if (to.isBefore(windowStart) || to.difference(windowStart).inDays > 365) {
    reject('Choose dates up to 366 days apart.');
  }
  financeZone(v['timezone'] ?? '');
  final frequency = v['frequency'],
      interval = int.tryParse(v['interval'] ?? '') ?? 0;
  if (interval < 1 ||
      interval >
          (frequency == 'daily'
              ? 365
              : frequency == 'weekly'
              ? 52
              : 120) ||
      !['daily', 'weekly', 'monthly'].contains(frequency)) {
    reject(
      'Enter how often it repeats: up to every 365 days, 52 weeks or 120 months.',
    );
  }
  final weekdays = (v['weekdays'] ?? '')
      .split(',')
      .where((v) => v.isNotEmpty)
      .map(int.tryParse)
      .toList();
  if (frequency == 'weekly' &&
      (weekdays.isEmpty ||
          weekdays.any((d) => d == null || d < 1 || d > 7) ||
          weekdays.toSet().length != weekdays.length)) {
    reject('Choose at least one day of the week.');
  }
  final monthDay = int.tryParse(v['monthDay'] ?? '') ?? 0;
  if (frequency == 'monthly' &&
      (monthDay < 1 ||
          monthDay > 31 ||
          !['last_valid_day', 'skip'].contains(v['monthPolicy']))) {
    reject('Choose a day of the month, and what happens in shorter months.');
  }
  final end = (v['end'] ?? '').isEmpty ? null : planningDate(v['end']!);
  if (end != null && end.compareTo(v['start']!) < 0) {
    reject('The end date can’t be before the start date.');
  }
  final limit = (v['count'] ?? '').isEmpty
      ? null
      : int.tryParse(v['count']!) ?? 0;
  if (limit != null && (limit < 1 || limit > 10000)) {
    reject('Enter 1 to 10,000 times, or leave this blank.');
  }
  final result = <String>[];
  var emitted = 0, work = 0;
  final monday = start.subtract(Duration(days: start.weekday - 1));
  for (
    var day = start;
    !day.isAfter(to);
    day = day.add(const Duration(days: 1))
  ) {
    if (++work > 100000) {
      reject(
        'This start date is too far back to work out. Choose a later one.',
      );
    }
    final label = day.toIso8601String().substring(0, 10);
    if (end != null && label.compareTo(end) > 0) break;
    var match = false;
    if (frequency == 'daily') {
      match = day.difference(start).inDays % interval == 0;
    }
    if (frequency == 'weekly') {
      match =
          day.difference(monday).inDays ~/ 7 % interval == 0 &&
          weekdays.contains(day.weekday);
    }
    if (frequency == 'monthly') {
      final month = (day.year - start.year) * 12 + day.month - start.month;
      final last = DateTime.utc(day.year, day.month + 1, 0).day;
      final wanted = v['monthPolicy'] == 'last_valid_day' && monthDay > last
          ? last
          : monthDay;
      match = month % interval == 0 && day.day == wanted;
    }
    if (!match) continue;
    emitted++;
    if (limit != null && emitted > limit) break;
    if (!day.isBefore(windowStart)) {
      result.add(label);
      if (result.length > 500) {
        reject('That’s more than 500 dates. Choose a shorter period.');
      }
    }
  }
  return result;
}

List<LocalRevision> effectiveRecurringLinks(
  LocalSnapshot s,
  String occurrence,
) => s.current
    .where(
      (r) =>
          financeType(r) == 'recurrenceLink' &&
          r.values['occurrence'] == occurrence &&
          !s.current.any(
            (u) =>
                financeType(u) == 'recurrenceUnlink' &&
                u.values['link'] == r.id,
          ),
    )
    .toList();
LocalRevision recurrenceRule(LocalSnapshot s, String id) {
  final r = s.revision(id);
  if (financeType(r) != 'recurrence') {
    reject('Choose a recurring item.');
  }
  return r;
}

void planRecurrence(FinanceRuleContext c) {
  final s = c.s, v = c.v, op = c.operation;
  if (op == 'recurrence') {
    c.total = c.money('amount');
    if (![
          'income',
          'bill',
          'subscription',
        ].contains(c.value('recurringKind')) ||
        !['active', 'archived'].contains(c.value('status'))) {
      reject('Choose the type of item and whether it’s active.');
    }
    final start = planningDate(c.text('start'));
    recurringDates(v, start, start);
    if (c.value('account').isNotEmpty) s.account(c.value('account'));
    if (c.value('category').isNotEmpty) {
      s.category(
        c.value('category'),
        c.value('recurringKind') == 'income' ? 'income' : 'expense',
      );
    }
    if (c.old != null &&
        start.compareTo(c.date) <= 0 &&
        c.value('status') != 'archived') {
      reject(
        'A change starts on a future date. Choose a start date after today.',
      );
    }
    c.effects.add(
      'This is what you expect. A date arriving doesn’t log a payment.',
    );
    return;
  }
  if (op == 'recurrenceUnlink') {
    if (c.old != null) {
      reject('This can’t be changed. Link the record again if you need to.');
    }
    final link = c.ref('link', {'recurrenceLink'});
    if (s.current.any(
      (r) => financeType(r) == op && r.values['link'] == link.id,
    )) {
      reject('This link was already removed.');
    }
    c.text('reason');
    c.source = link.id;
    c.total = link.amount;
    return;
  }
  if (c.old != null) {
    reject(
      'To change this, change or skip the date again, or remove the link.',
    );
  }
  final rule = recurrenceRule(s, c.text('rule'));
  if (op == 'recurrenceGenerate') {
    if (!s.current.contains(rule) || rule.values['status'] != 'active') {
      reject(
        'Only an active recurring item can add dates. Open its current version.',
      );
    }
    final dates = recurringDates(
      rule.values,
      c.text('from'),
      c.text('through'),
    );
    v['dates'] = jsonEncode(dates);
    c.total = BigInt.zero;
    c.source = rule.id;
    return;
  }
  final logical = planningDate(c.text('logicalDate'));
  if (!recurringDates(rule.values, logical, logical).contains(logical) ||
      !s.current.any(
        (r) =>
            financeType(r) == 'recurrenceGenerate' &&
            r.values['rule'] == rule.id &&
            (jsonDecode(r.values['dates']!) as List).contains(logical),
      )) {
    reject('Add this date to Upcoming first.');
  }
  final occurrence = occurrenceIdentity(rule, logical);
  v['occurrence'] = occurrence;
  final overrides = s.current
      .where(
        (r) =>
            financeType(r) == 'occurrenceOverride' &&
            r.values['occurrence'] == occurrence,
      )
      .toList();
  final override = overrides.lastOrNull;
  final linked = sumMinor(
    effectiveRecurringLinks(s, occurrence).map((r) => r.amount),
  );
  final expected = override?.amount ?? rule.amount;
  final terminal = ['skipped', 'cancelled'].contains(override?.values['state']);
  if (op == 'occurrenceOverride') {
    if (terminal) {
      reject('This date was skipped or cancelled, so it can’t change.');
    }
    c.total = c.money('amount');
    planningDate(c.text('due'));
    if (!['planned', 'skipped', 'cancelled'].contains(c.value('state')) ||
        c.total < linked ||
        (c.value('state') != 'planned' && linked != BigInt.zero)) {
      reject(
        'Remove the records linked to this date first, or keep the amount at or above them.',
      );
    }
    c.text('reason');
    c.source = override?.id ?? rule.id;
    return;
  }
  if (op != 'recurrenceLink' || terminal) {
    reject('This date was skipped or cancelled, so it can’t take a record.');
  }
  final actual = s.revision(c.text('actual'));
  if (!s.current.contains(actual) ||
      (rule.values['recurringKind'] == 'income'
          ? actual.kind != 'income'
          : !['expense', 'cardPurchase'].contains(financeType(actual)))) {
    reject(
      'Choose income for an income item, or an expense or card purchase for a bill.',
    );
  }
  c.total = c.money('amount');
  final used = sumMinor(
    s.current
        .where(
          (r) =>
              financeType(r) == op &&
              r.values['actual'] == actual.id &&
              !s.current.any(
                (u) =>
                    financeType(u) == 'recurrenceUnlink' &&
                    u.values['link'] == r.id,
              ),
        )
        .map((r) => r.amount),
  );
  if (linked + c.total > expected || used + c.total > actual.amount) {
    reject(
      'That’s more than this date expects, or more than is left on the record.',
    );
  }
  c.source = actual.id;
  c.effects.add(
    'This links a record you already logged. Nothing new is added.',
  );
}
