part of '../local/finance_domain.dart';

class RecurringOccurrence {
  const RecurringOccurrence(
    this.id,
    this.rule,
    this.logicalDate,
    this.due,
    this.expected,
    this.linked,
    this.state,
    this.persisted,
  );
  final String id, logicalDate, due, state;
  final LocalRevision rule;
  final BigInt expected, linked;
  final bool persisted;
  BigInt get remaining => expected - linked;
}

List<RecurringOccurrence> recurringOccurrences(
  LocalSnapshot s,
  String from,
  String through, {
  bool previews = false,
}) {
  planningDate(from);
  planningDate(through);
  final rules = s.revisions
      .where((r) => financeType(r) == 'recurrence')
      .toList();
  if (rules.length > 1000 ||
      rules.map((r) => r.actionId).toSet().length > 500) {
    reject('You have more recurring items than Salapiya can work out (500).');
  }
  final candidates = <String, (LocalRevision, String, bool)>{};
  String? boundary(LocalRevision rule) {
    final next =
        rules
            .where((r) => r.actionId == rule.actionId && r.number > rule.number)
            .toList()
          ..sort((a, b) => a.number.compareTo(b.number));
    return next.isEmpty
        ? null
        : next.first.values['status'] == 'archived'
        ? next.first.date
        : next.first.values['start'];
  }

  for (final generation in s.current.where(
    (r) => financeType(r) == 'recurrenceGenerate',
  )) {
    final rule = recurrenceRule(s, generation.values['rule']!);
    for (final logical
        in (jsonDecode(generation.values['dates']!) as List).cast<String>()) {
      candidates[occurrenceIdentity(rule, logical)] = (rule, logical, true);
      if (candidates.length > 10000) {
        reject(
          'There are more than 10,000 dates on record, so this can’t be shown in full.',
        );
      }
    }
  }
  if (previews) {
    for (final rule in rules.where((r) => r.values['status'] == 'active')) {
      final end = boundary(rule);
      var windowEnd = through;
      if (end != null && end.compareTo(windowEnd) <= 0) {
        windowEnd = DateTime.parse('${end}T00:00:00Z')
            .subtract(const Duration(days: 1))
            .toIso8601String()
            .substring(0, 10);
      }
      if (windowEnd.compareTo(from) < 0) continue;
      for (final logical in recurringDates(rule.values, from, windowEnd)) {
        final id = occurrenceIdentity(rule, logical);
        candidates.putIfAbsent(id, () => (rule, logical, false));
      }
    }
  }
  final result = <RecurringOccurrence>[];
  for (final entry in candidates.entries) {
    final (rule, logical, persisted) = entry.value;
    final override = s.current
        .where(
          (r) =>
              financeType(r) == 'occurrenceOverride' &&
              r.values['occurrence'] == entry.key,
        )
        .lastOrNull;
    final due = override?.values['due'] ?? logical;
    if (due.compareTo(from) < 0 || due.compareTo(through) > 0) continue;
    final expected = override?.amount ?? rule.amount,
        linked = sumMinor(
          effectiveRecurringLinks(s, entry.key).map((r) => r.amount),
        );
    var state = override?.values['state'] ?? 'planned';
    final end = boundary(rule);
    if (state == 'planned' &&
        linked == BigInt.zero &&
        end != null &&
        logical.compareTo(end) >= 0 &&
        due.compareTo(end) >= 0) {
      state = 'cancelled';
    }
    if (state == 'planned') {
      state = linked == expected
          ? 'completed'
          : linked > BigInt.zero
          ? 'linked'
          : 'planned';
    }
    result.add(
      RecurringOccurrence(
        entry.key,
        rule,
        logical,
        due,
        expected,
        linked,
        state,
        persisted,
      ),
    );
    if (result.length > 5000) {
      reject('There are more than 5,000 dates here. Choose a shorter period.');
    }
  }
  result.sort((a, b) {
    final d = a.due.compareTo(b.due);
    return d != 0 ? d : a.id.compareTo(b.id);
  });
  return result;
}

/// Provider-date comparison only. Membership and settlement remain explicit.
BigInt statementRecordedBalance(LocalSnapshot s, LocalRevision statement) =>
    -sumMinor(
      s.current
          .where((r) => r.values['card'] == statement.values['card'])
          .expand(
            (r) => r.postings.where(
              (p) =>
                  p.ledger == 'card_liability' &&
                  (r.values['postingDate'] ?? p.date).compareTo(
                        statement.values['end']!,
                      ) <=
                      0,
            ),
          )
          .map((p) => p.amount),
    );

class FinancialReminderSource {
  const FinancialReminderSource(
    this.id,
    this.version,
    this.source,
    this.title,
    this.date,
    this.amount,
    this.kind,
  );
  final String id, version, source, title, date, kind;
  final BigInt amount;
}

List<FinancialReminderSource> financialReminderSources(
  LocalSnapshot s,
  String from,
  String through, {
  String? asOf,
}) {
  final today = asOf ?? civilToday();
  planningDate(today);
  final result = <FinancialReminderSource>[];
  for (final r in s.current) {
    if (financeType(r) == 'debtSchedule' &&
        !s.current.any(
          (p) =>
              financeType(p) == 'debtPayoff' &&
              p.date.compareTo(today) <= 0 &&
              p.values['debt'] == r.values['debt'],
        )) {
      for (final row in financeSchedule(r.values['schedule']!)) {
        final paid =
            row.paid +
            sumMinor(
              s.current
                  .where(
                    (p) =>
                        financeType(p) == 'debtPayment' &&
                        p.date.compareTo(today) <= 0 &&
                        (p.values['scheduleSource'] ?? '').isNotEmpty &&
                        s.revision(p.values['scheduleSource']!).actionId ==
                            r.actionId,
                  )
                  .map(
                    (p) =>
                        debtAllocations(
                          p.values['allocations'] ?? '',
                        )[row.id] ??
                        BigInt.zero,
                  ),
            );
        if (row.amount > paid) {
          result.add(
            FinancialReminderSource(
              'debt:${r.actionId}:${row.id}',
              '${r.number}:${row.date}:$paid',
              r.id,
              r.title,
              row.date,
              row.amount - paid,
              'Debt due',
            ),
          );
        }
      }
    }
    if (financeType(r) == 'statement' && r.values['verified'] == 'true') {
      final allocated = sumMinor(
        s.current
            .where(
              (p) =>
                  financeType(p) == 'cardAllocation' &&
                  p.date.compareTo(today) <= 0 &&
                  p.values['statement'] == r.id,
            )
            .map((p) => p.amount),
      );
      if (r.amount > allocated) {
        result.add(
          FinancialReminderSource(
            'statement:${r.actionId}',
            '${r.number}:${r.values['due']}:$allocated',
            r.id,
            r.title,
            r.values['due']!,
            r.amount - allocated,
            'Card statement due',
          ),
        );
      }
    }
    if (financeType(r) == 'installment' &&
        r.values['verified'] == 'true' &&
        r.values['status'] != 'suspended') {
      for (final row in financeSchedule(r.values['schedule']!)) {
        final applied = sumMinor(
          s.current
              .where(
                (p) =>
                    financeType(p) == 'installmentApplication' &&
                    p.values['plan'] == r.id &&
                    p.values['row'] == row.id &&
                    p.date.compareTo(today) <= 0,
              )
              .map((p) => p.amount),
        );
        final remaining = row.amount - row.paid - applied;
        if (remaining > BigInt.zero) {
          result.add(
            FinancialReminderSource(
              'installment:${r.actionId}:${row.id}',
              '${r.number}:${row.date}:${row.paid}:$applied',
              r.id,
              r.title,
              row.date,
              remaining,
              'Card installment due',
            ),
          );
        }
      }
    }
  }
  for (final o in recurringOccurrences(s, from, through, previews: false)) {
    if (['planned', 'linked'].contains(o.state) && o.remaining > BigInt.zero) {
      result.add(
        FinancialReminderSource(
          'recurring:${o.id}',
          '${o.rule.number}:${o.due}:${o.expected}:${o.linked}',
          o.rule.id,
          o.rule.title,
          o.due,
          o.remaining,
          'Recurring expectation',
        ),
      );
    }
  }
  return result
      .where(
        (r) => r.date.compareTo(from) >= 0 && r.date.compareTo(through) <= 0,
      )
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}

class ForecastContribution {
  const ForecastContribution(
    this.source,
    this.label,
    this.date,
    this.amount,
    this.basis,
  );
  final String source, label, date, basis;
  final BigInt amount;
}

/// Ends the note for an item the user left out; its page lists those apart.
const forecastLeftOutByYou = 'you left this out.';

class FinanceForecast {
  const FinanceForecast(
    this.opening,
    this.windowOpening,
    this.daily,
    this.contributions,
    this.exclusions,
    this.reserved,
  );
  final BigInt opening, windowOpening, reserved;
  final Map<String, BigInt> daily;
  final List<ForecastContribution> contributions;
  final List<String> exclusions;
}

FinanceForecast financialForecast(
  LocalSnapshot s, {
  required String today,
  required String from,
  required String through,
  bool independentRecurring = false,
  List<String> cardStatements = const [],
  List<String> cardInstallments = const [],
  Set<String> excludedSources = const {},
  List<ForecastContribution> adjustments = const [],
}) {
  planningDate(today);
  planningDate(from);
  planningDate(through);
  final clock = DateTime.parse('${today}T00:00:00Z'),
      end = DateTime.parse('${through}T00:00:00Z');
  if (from.compareTo(today) <= 0 ||
      through.compareTo(from) < 0 ||
      end.difference(clock).inDays > 366) {
    reject('A forecast starts tomorrow or later and ends within 366 days.');
  }
  if (adjustments.length > 20 ||
      cardStatements.length + cardInstallments.length > 100 ||
      excludedSources.length > 100 ||
      s.current.where((r) => financeType(r) == 'creditCard').length > 100) {
    reject(
      'That’s too many choices for one forecast: up to 20 what-ifs, 100 card choices and 100 left-out items.',
    );
  }
  final posts = s.current
      .expand((r) => r.postings)
      .where((p) => p.ledger == 'cash')
      .toList();
  final opening = sumMinor(
    posts.where((p) => p.date.compareTo(today) <= 0).map((p) => p.amount),
  );
  final contributions = <ForecastContribution>[],
      excluded = <String>[
        'Debt schedules, future living costs and your card issuer’s rules aren’t included.',
      ];
  for (final r in s.current) {
    for (final p in r.postings.where(
      (p) =>
          p.ledger == 'cash' &&
          p.date.compareTo(today) > 0 &&
          p.date.compareTo(through) <= 0,
    )) {
      contributions.add(
        ForecastContribution(
          r.id,
          r.title,
          p.date,
          p.amount,
          'Recorded future cash',
        ),
      );
    }
  }
  final selectedCards = <String>{};
  bool unresolvedCard(String card, {bool applications = false}) {
    if (financeBalance(s, 'card_liability', 'card', card, through: today) >=
        BigInt.zero) {
      return true;
    }
    for (final credit in s.current.where(
      (r) =>
          r.values['card'] == card &&
          ['cardPayment', 'cardRefund'].contains(financeType(r)),
    )) {
      final credited = sumMinor(
        credit.postings
            .where((p) => p.ledger == 'card_liability')
            .map((p) => p.amount),
      );
      final allocations = s.current.where(
        (r) =>
            financeType(r) == 'cardAllocation' &&
            r.values['payment'] == credit.id,
      );
      if (credited != sumMinor(allocations.map((r) => r.amount))) return true;
      if (applications &&
          allocations.any(
            (allocation) =>
                allocation.amount !=
                sumMinor(
                  s.current
                      .where(
                        (r) =>
                            financeType(r) == 'installmentApplication' &&
                            r.values['payment'] == allocation.id,
                      )
                      .map((r) => r.amount),
                ),
          )) {
        return true;
      }
    }
    return false;
  }

  for (final id in cardStatements) {
    final statement = financeSource(s, id, {'statement'}),
        card = statement.values['card']!;
    if (!selectedCards.add(card)) {
      reject('Choose one statement for each card.');
    }
    final credits = s.current.where(
      (r) =>
          r.values['card'] == card &&
          ['cardPayment', 'cardRefund'].contains(financeType(r)),
    );
    final unapplied = sumMinor(
      credits.map(
        (r) =>
            sumMinor(
              r.postings
                  .where((p) => p.ledger == 'card_liability')
                  .map((p) => p.amount),
            ) -
            sumMinor(
              s.current
                  .where(
                    (a) =>
                        financeType(a) == 'cardAllocation' &&
                        a.values['payment'] == r.id,
                  )
                  .map((a) => a.amount),
            ),
      ),
    );
    final allocated = sumMinor(
      s.current
          .where(
            (a) =>
                financeType(a) == 'cardAllocation' &&
                a.values['statement'] == statement.id,
          )
          .map((a) => a.amount),
    );
    final amount = statement.amount - allocated, due = statement.values['due']!;
    if (unapplied != BigInt.zero ||
        unresolvedCard(card) ||
        statement.values['verified'] != 'true' ||
        amount <= BigInt.zero ||
        due.compareTo(today) <= 0) {
      excluded.add(
        '${statement.title}: needs a confirmed due date and matched payments, so no payment is assumed.',
      );
      continue;
    }
    if (due.compareTo(through) <= 0) {
      contributions.add(
        ForecastContribution(
          statement.id,
          statement.title,
          due,
          -amount,
          'Explicit card payment assumption',
        ),
      );
    }
  }
  for (final cardId in cardInstallments) {
    final card = financeSource(s, cardId, {'creditCard'});
    if (!selectedCards.add(card.actionId)) {
      reject(
        'For each card, choose a statement or its installment plans, not both.',
      );
    }
    final plans = s.current
        .where(
          (r) =>
              financeType(r) == 'installment' &&
              r.values['card'] == card.actionId,
        )
        .toList();
    if (plans.isEmpty || unresolvedCard(card.actionId, applications: true)) {
      excluded.add(
        '${card.title}: its installment plans need a balance owed and every payment matched, so no payment is assumed.',
      );
      continue;
    }
    for (final plan in plans) {
      if (plan.values['verified'] != 'true' ||
          plan.values['status'] == 'suspended') {
        excluded.add(
          '${plan.title}: this plan isn’t confirmed, or it’s suspended.',
        );
        continue;
      }
      for (final row in financeSchedule(plan.values['schedule']!)) {
        final applied = sumMinor(
          s.current
              .where(
                (r) =>
                    financeType(r) == 'installmentApplication' &&
                    r.values['plan'] == plan.id &&
                    r.values['row'] == row.id,
              )
              .map((r) => r.amount),
        );
        final remaining = row.amount - row.paid - applied;
        if (remaining > BigInt.zero &&
            row.date.compareTo(today) > 0 &&
            row.date.compareTo(through) <= 0) {
          contributions.add(
            ForecastContribution(
              'installment:${plan.id}:${row.id}',
              plan.title,
              row.date,
              -remaining,
              'Explicit installment payment assumption',
            ),
          );
        } else if (remaining > BigInt.zero && row.date.compareTo(today) <= 0) {
          excluded.add(
            '${plan.title}, ${row.id}: this payment is overdue, so no date is guessed for it.',
          );
        }
      }
    }
  }
  final tomorrow = clock
      .add(const Duration(days: 1))
      .toIso8601String()
      .substring(0, 10);
  for (final o in recurringOccurrences(s, tomorrow, through, previews: true)) {
    if (!['planned', 'linked'].contains(o.state) ||
        o.remaining == BigInt.zero) {
      continue;
    }
    final inflow = o.rule.values['recurringKind'] == 'income';
    final account = s.accounts
        .where((a) => a.id == o.rule.values['account'] && !a.archived)
        .firstOrNull;
    final overlap =
        contributions.any(
          (c) =>
              c.basis == 'Recorded future cash' &&
              (inflow ? c.amount > BigInt.zero : c.amount < BigInt.zero),
        ) ||
        (!inflow && selectedCards.isNotEmpty);
    if (account == null ||
        o.rule.values['timezone'] != 'Asia/Manila' ||
        overlap && !independentRecurring) {
      excluded.add(
        '${o.rule.title}: ${account == null
            ? 'it has no active account'
            : o.rule.values['timezone'] != 'Asia/Manila'
            ? 'it uses another time zone'
            : 'it may be the same money as something already included'}.',
      );
      continue;
    }
    contributions.add(
      ForecastContribution(
        o.id,
        o.rule.title,
        o.due,
        inflow ? o.remaining : -o.remaining,
        'Recurring expected cash',
      ),
    );
  }
  for (final id in excludedSources) {
    if (contributions.any(
      (r) => r.source == id && r.basis == 'Recorded future cash',
    )) {
      reject(
        'This is a record you logged, so it stays in. Correct the record to change it.',
      );
    }
    final matches = contributions
        .where((r) => r.source == id && r.basis != 'Recorded future cash')
        .toList();
    if (matches.isEmpty) {
      excluded.add('Something you left out isn’t in this forecast any more.');
    }
    for (final r in matches) {
      excluded.add('${r.label}: $forecastLeftOutByYou');
    }
    contributions.removeWhere(
      (r) => r.source == id && r.basis != 'Recorded future cash',
    );
  }
  for (final adjustment in adjustments) {
    planningDate(adjustment.date);
    if (adjustment.date.compareTo(today) <= 0 ||
        adjustment.date.compareTo(through) > 0 ||
        adjustment.label.trim().isEmpty) {
      reject(
        'Each what-if needs a date in this forecast, a name and an amount.',
      );
    }
    component(adjustment.amount);
    contributions.add(
      ForecastContribution(
        adjustment.source,
        adjustment.label,
        adjustment.date,
        adjustment.amount,
        'Hypothetical; not actual money',
      ),
    );
  }
  if (contributions.length > 5000) {
    reject('There’s too much for one forecast. Choose a shorter period.');
  }
  var closing = opening, windowOpening = opening;
  final daily = <String, BigInt>{};
  for (
    var day = clock.add(const Duration(days: 1));
    !day.isAfter(end);
    day = day.add(const Duration(days: 1))
  ) {
    final label = day.toIso8601String().substring(0, 10);
    if (label == from) windowOpening = closing;
    closing += sumMinor(
      contributions.where((c) => c.date == label).map((c) => c.amount),
    );
    if (label.compareTo(from) >= 0) daily[label] = closing;
  }
  return FinanceForecast(
    opening,
    windowOpening,
    daily,
    contributions,
    excluded,
    savingsReserved(s),
  );
}
