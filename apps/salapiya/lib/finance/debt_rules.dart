part of '../local/finance_domain.dart';

const nativeDebtCommands = {
  'debtImport',
  'borrowing',
  'debtPayment',
  'debtClassification',
  'debtSchedule',
  'debtPayoff',
  'debtAdjustment',
};

void planDebt(FinanceRuleContext c) {
  final s = c.s, v = c.v, op = c.operation;
  if (v['debtComponentContract'] != null && v['debtComponentContract'] != '1') {
    reject(
      'This debt record came from a different version of Salapiya. Update the app before changing it.',
    );
  }
  if (['debtImport', 'borrowing'].contains(op)) {
    c.text('lender', max: 200);
    if (![
      'personal_loan',
      'installment_loan',
      'bnpl',
      'flexible_manual',
    ].contains(c.value('debtType'))) {
      reject('Choose a debt type.');
    }
    if (c.value('principal').isNotEmpty) c.money('principal');
    v['debt'] = c.old?.actionId ?? c.command.id;
    c.total = c.money('amount');
    if (op == 'debtImport' &&
        v['debtComponentContract'] == '1' &&
        c.value('outstandingPrincipal').isNotEmpty &&
        c.money('outstandingPrincipal', zero: true) > c.total) {
      reject('Principal left can’t be more than what you owe now.');
    }
    if (op == 'debtImport') {
      c.post('debt_liability', -c.total);
      c.post('equity', c.total);
      c.effects.add(
        'Adds what you owe now. No money moves, and it isn’t income or spending.',
      );
    } else {
      final withheld = c.money('withheld', zero: true),
          financed = c.money('financedFee', zero: true);
      if (withheld >= c.total || c.total + financed > maxComponent) {
        reject(
          'The fee taken out up front must be less than the amount borrowed.',
        );
      }
      c.post('debt_liability', -(c.total + financed));
      if (c.value('fundingUse') == 'purchase') {
        if (withheld != BigInt.zero) {
          reject(
            'A fee can only be taken out up front when you received cash.',
          );
        }
        c.expense(c.total);
      } else if (c.value('fundingUse') == 'cash') {
        c.cash(c.total - withheld);
      } else {
        reject('Choose how you used the loan.');
      }
      if (withheld + financed != BigInt.zero) {
        c.expense(withheld + financed, key: 'feeCategory');
      }
      c.effects.add(
        'A loan isn’t income. A fee taken out up front or added to the loan counts once.',
      );
    }
    return;
  }
  final debt = c.ref('debt', {'debtImport', 'borrowing'});
  v['debt'] = debt.actionId;
  if (c.date.compareTo(debt.date) < 0) {
    reject('Choose a date on or after the day this debt started.');
  }
  if (s.current.any(
    (r) =>
        r.id != c.old?.id &&
        financeType(r) == 'debtPayoff' &&
        r.values['debt'] == debt.actionId,
  )) {
    reject('This debt is closed, so nothing more can be logged on it.');
  }
  final liability = -financeBalance(
    s,
    'debt_liability',
    'debt',
    debt.actionId,
    excluding: c.old?.id,
  );
  final clearing = financeBalance(
    s,
    'debt_clearing',
    'debt',
    debt.actionId,
    excluding: c.old?.id,
  );
  switch (op) {
    case 'debtAdjustment':
      c.total = c.money('amount');
      c.text('reason');
      c.text('reference');
      if (c.value('verified') != 'true') {
        reject('Confirm this charge or waiver with your lender first.');
      }
      final adjustment = c.value('adjustmentKind');
      if (['recognized_charge', 'rounding_charge'].contains(adjustment)) {
        if (!['interest', 'fee', 'penalty'].contains(c.value('chargeType'))) {
          reject('Choose the kind of charge: interest, fee or penalty.');
        }
        c.post('debt_liability', -c.total);
        c.expense(c.total);
        c.source = debt.id;
      } else if ([
        'recognized_waiver',
        'rounding_waiver',
      ].contains(adjustment)) {
        if (c.total > liability) {
          reject('A waiver can’t be more than what you owe.');
        }
        if (c.value('waiverBasis') == 'imported_unknown' &&
            financeType(debt) == 'debtImport') {
          if (c.total >
              debtOpeningWaiverCapacity(s, debt, excluding: c.old?.id)) {
            reject(
              'That’s more than is left of the opening balance to waive. If it’s for a charge you logged, choose that charge.',
            );
          }
          c.post('equity', -c.total);
          c.source = debt.id;
        } else if (c.value('waiverBasis') == 'recognized_charge') {
          final charge = c.ref('chargeSource', {'debtAdjustment', 'borrowing'});
          final remaining = debtChargeRemaining(
            s,
            charge,
            excluding: c.old?.id,
          );
          if (charge.values['debt'] != debt.actionId ||
              charge.date.compareTo(c.date) > 0 ||
              !recognizedDebtCharge(charge) ||
              remaining == null ||
              c.total > remaining) {
            reject(
              'Choose an unpaid charge on this debt, and waive no more than what’s left on it. Break down any earlier payments first.',
            );
          }
          c.post(
            'expense',
            -c.total,
            category: s
                .category(
                  financeType(charge) == 'borrowing'
                      ? charge.values['feeCategory']!
                      : charge.values['category']!,
                  'expense',
                )
                .id,
          );
          c.source = charge.id;
        } else {
          reject('Choose what the waiver is for.');
        }
        c.post('debt_liability', c.total);
      } else if (adjustment == 'avoided_future') {
        c.source = debt.id;
      } else {
        reject('Choose what happened.');
      }
      c.effects.add(
        'A charge or waiver changes what you owe. No money moves, and a charge you avoided changes nothing.',
      );
    case 'debtPayment':
      c.total = c.money('amount');
      final external = c.money('externalFee', zero: true);
      final reduction = c.money('reduction', zero: true),
          interest = c.money('interest', zero: true),
          fee = c.money('fee', zero: true),
          unresolved = c.money('clearing', zero: true);
      if (sumMinor([external, reduction, interest, fee, unresolved]) !=
              c.total ||
          reduction > liability) {
        reject(
          'The amount must equal what lowers your debt, plus new charges, fees and anything still without a breakdown.',
        );
      }
      if (c.value('certainty') == 'confirmed_total') {
        if (unresolved != BigInt.zero ||
            interest != BigInt.zero ||
            fee != BigInt.zero) {
          reject(
            'If all of it lowers what you owe, new interest, fees and amounts without a breakdown must be zero. Otherwise choose the exact breakdown.',
          );
        }
      } else if (![
        'known_components',
        'unresolved',
      ].contains(c.value('certainty'))) {
        reject('Choose what this payment covers.');
      }
      c.cash(-c.total);
      c.post('debt_liability', reduction);
      c.post('debt_clearing', unresolved);
      if (interest != BigInt.zero) c.expense(interest, key: 'interestCategory');
      if (fee + external != BigInt.zero) {
        c.expense(fee + external, key: 'feeCategory');
      }
      final contractual = c.total - external;
      final allocations = debtAllocations(c.value('allocations'));
      final unapplied = c.money('unapplied', zero: true);
      if (sumMinor(allocations.values) + unapplied != contractual) {
        reject(
          'The amounts applied to due dates, plus what stays unapplied, must equal the payment.',
        );
      }
      if (allocations.isNotEmpty) {
        final schedule = c.ref('scheduleSource', {'debtSchedule'});
        if (schedule.values['debt'] != debt.actionId) {
          reject('Choose a payment from this debt’s current schedule.');
        }
        final rows = financeSchedule(schedule.values['schedule']!);
        for (final allocation in allocations.entries) {
          final row = rows.where((r) => r.id == allocation.key).firstOrNull;
          if (row == null) {
            reject('Choose a payment in the current schedule.');
          }
          final paid = sumMinor(
            s.current
                .where(
                  (r) =>
                      r.id != c.old?.id &&
                      financeType(r) == 'debtPayment' &&
                      (r.values['scheduleSource'] ?? '').isNotEmpty &&
                      s.revision(r.values['scheduleSource']!).actionId ==
                          schedule.actionId,
                )
                .map(
                  (r) =>
                      debtAllocations(r.values['allocations'] ?? '')[row.id] ??
                      BigInt.zero,
                ),
          );
          if (paid + allocation.value + row.paid > row.amount) {
            reject('That’s more than is left on this payment.');
          }
        }
      }
      c.effects.add(
        'Anything without a breakdown stays that way until you break it down. Paying a due date and lowering what you owe are tracked separately.',
      );
    case 'debtClassification':
      final payment = c.ref('payment', {'debtPayment'});
      if (payment.values['debt'] != debt.actionId ||
          payment.date.compareTo(c.date) > 0) {
        reject('Choose a payment logged on this debt.');
      }
      final reduction = c.money('reduction', zero: true),
          interest = c.money('interest', zero: true),
          fee = c.money('fee', zero: true);
      c.total = reduction + interest + fee;
      if (c.total == BigInt.zero ||
          reduction > liability ||
          c.total > clearing ||
          c.total + c.used(op, 'payment', payment.id) >
              parsePhp(payment.values['clearing']!)) {
        reject('That’s more than is left to break down, or more than you owe.');
      }
      c.text('reason');
      c.source = payment.id;
      c.post('debt_clearing', -c.total);
      c.post('debt_liability', reduction);
      if (interest != BigInt.zero) c.expense(interest, key: 'interestCategory');
      if (fee != BigInt.zero) c.expense(fee, key: 'feeCategory');
      c.effects.add(
        'This breaks down a payment you already logged. No money moves again.',
      );
    case 'debtSchedule':
      final rows = financeSchedule(c.text('schedule', max: 20000));
      if (c.old != null) {
        final formerRows = financeSchedule(c.old!.values['schedule']!);
        for (final former in formerRows) {
          final revised = rows.where((r) => r.id == former.id).firstOrNull;
          final allocated = sumMinor(
            s.current
                .where(
                  (r) =>
                      financeType(r) == 'debtPayment' &&
                      (r.values['scheduleSource'] ?? '').isNotEmpty &&
                      s.revision(r.values['scheduleSource']!).actionId ==
                          c.old!.actionId,
                )
                .map(
                  (r) =>
                      debtAllocations(
                        r.values['allocations'] ?? '',
                      )[former.id] ??
                      BigInt.zero,
                ),
          );
          if (revised == null && former.paid + allocated > BigInt.zero ||
              revised != null &&
                  (revised.paid != former.paid ||
                      revised.amount < former.paid + allocated)) {
            reject(
              'An edited schedule must keep every earlier payment and what was paid toward it.',
            );
          }
        }
        if (rows.any(
          (r) =>
              !formerRows.any((old) => old.id == r.id) && r.paid != BigInt.zero,
        )) {
          reject(
            'A new payment in the schedule can’t already show money paid.',
          );
        }
      }
      c.total = sumMinor(rows.map((r) => r.amount));
      if (s.current.any(
        (r) =>
            r.id != c.old?.id &&
            financeType(r) == op &&
            r.values['debt'] == debt.actionId,
      )) {
        reject('This debt already has a schedule. Edit that one.');
      }
      if (financeType(debt) != 'debtImport' &&
          rows.any((r) => r.paid != BigInt.zero)) {
        reject(
          'Only a debt you added with its balance can show earlier payments.',
        );
      }
      if (c.value('verified') != 'true') {
        reject('Confirm these dates and amounts with your lender first.');
      }
      c.text('reference');
      validateDebtCadence(c, rows);
      c.effects.add(
        'A schedule lists what’s due and doesn’t change what you owe. Earlier payments aren’t taken out again.',
      );
    case 'debtPayoff':
      c.total = c.money('amount', zero: true);
      final reduction = c.money('reduction', zero: true),
          waiver = c.money('waiver', zero: true),
          interest = c.money('interest', zero: true),
          fee = c.money('fee', zero: true);
      c.money('avoided', zero: true);
      if (clearing != BigInt.zero ||
          c.total != reduction + interest + fee ||
          reduction + waiver != liability) {
        reject(
          'The payoff amount must equal what you owe less any waiver, plus new interest and fees. Break down any earlier payments first.',
        );
      }
      if (c.value('verified') != 'true' ||
          c.money('providerPayoff', zero: true) != c.total) {
        reject('Confirm the payoff amount with your lender first.');
      }
      c.text('reference');
      c.text('reason');
      if (c.total != BigInt.zero) c.cash(-c.total);
      c.post('debt_liability', reduction + waiver);
      if (interest != BigInt.zero) c.expense(interest, key: 'interestCategory');
      if (fee != BigInt.zero) c.expense(fee, key: 'feeCategory');
      if (waiver != BigInt.zero) {
        if (c.value('waiverBasis') != 'imported_unknown' ||
            financeType(debt) != 'debtImport' ||
            waiver > debtOpeningWaiverCapacity(s, debt, excluding: c.old?.id)) {
          reject(
            'This waiver needs a charge to apply to, and this debt has none that fits.',
          );
        }
        c.post('equity', -waiver);
      }
      c.effects.add(
        'This closes the debt. Its old schedule stays as cancelled payments, and charges you avoided change nothing.',
      );
    default:
      reject('This debt record isn’t supported here.');
  }
  if (['debtPayment', 'debtClassification', 'debtPayoff'].contains(op)) {
    validateDebtReductionSources(c, debt);
  }
}

/// An exact range rather than an invented winner when historic reductions lack
/// principal allocation. Import original principal is not outstanding principal.
(BigInt, BigInt)? debtPrincipalRange(
  LocalSnapshot s,
  LocalRevision debt,
  String through, {
  String? excluding,
}) {
  final initial = financeType(debt) == 'borrowing'
      ? debt.amount
      : debt.values['debtComponentContract'] == '1' &&
            debt.values['outstandingPrincipal']?.isNotEmpty == true
      ? parsePhp(debt.values['outstandingPrincipal']!)
      : null;
  if (initial == null) return null;
  if (debt.date.compareTo(through) > 0) return (BigInt.zero, BigInt.zero);
  var known = BigInt.zero, unknown = BigInt.zero;
  for (final r in s.current.where(
    (r) =>
        r.id != excluding &&
        r.values['debt'] == debt.actionId &&
        r.date.compareTo(through) <= 0,
  )) {
    if (financeType(r) == 'debtPayoff') return (BigInt.zero, BigInt.zero);
    if (['debtPayment', 'debtClassification'].contains(financeType(r))) {
      final reduction = parsePhp(r.values['reduction'] ?? '0.00'),
          principal = parsePhp(
            r.values['debtComponentContract'] == '1' &&
                    r.values['principalReduction']?.isNotEmpty == true
                ? r.values['principalReduction']!
                : '0.00',
          ),
          sources = sumMinor(
            debtAllocations(
              r.values['debtComponentContract'] == '1'
                  ? r.values['reductionSources'] ?? ''
                  : '',
            ).values,
          );
      known += principal;
      unknown += reduction - principal - sources;
    }
    if (financeType(r) == 'debtAdjustment' &&
        [
          'recognized_waiver',
          'rounding_waiver',
        ].contains(r.values['adjustmentKind']) &&
        r.values['waiverBasis'] == 'imported_unknown') {
      unknown += r.amount;
    }
  }
  final upper = initial - known, lower = upper - unknown;
  return (
    lower > BigInt.zero ? lower : BigInt.zero,
    upper > BigInt.zero ? upper : BigInt.zero,
  );
}

bool recognizedDebtCharge(LocalRevision r) => financeType(r) == 'borrowing'
    ? parsePhp(r.values['financedFee']!) > BigInt.zero
    : financeType(r) == 'debtAdjustment' &&
          [
            'recognized_charge',
            'rounding_charge',
          ].contains(r.values['adjustmentKind']);

BigInt debtOpeningWaiverCapacity(
  LocalSnapshot s,
  LocalRevision debt, {
  String? excluding,
}) {
  var remaining = debt.amount;
  for (final r in s.current.where(
    (r) => r.id != excluding && r.values['debt'] == debt.actionId,
  )) {
    if ([
      'debtPayment',
      'debtClassification',
      'debtPayoff',
    ].contains(financeType(r))) {
      remaining -=
          parsePhp(r.values['reduction'] ?? '0.00') -
          (r.values['debtComponentContract'] == '1'
              ? sumMinor(
                  debtAllocations(r.values['reductionSources'] ?? '').values,
                )
              : BigInt.zero);
      if (financeType(r) == 'debtPayoff' &&
          r.values['waiverBasis'] == 'imported_unknown') {
        remaining -= parsePhp(r.values['waiver'] ?? '0.00');
      }
    }
    if (financeType(r) == 'debtAdjustment' &&
        [
          'recognized_waiver',
          'rounding_waiver',
        ].contains(r.values['adjustmentKind']) &&
        r.values['waiverBasis'] == 'imported_unknown') {
      remaining -= r.amount;
    }
  }
  return remaining > BigInt.zero ? remaining : BigInt.zero;
}

BigInt? debtChargeRemaining(
  LocalSnapshot s,
  LocalRevision charge, {
  String? excluding,
}) {
  var remaining = financeType(charge) == 'borrowing'
      ? parsePhp(charge.values['financedFee']!)
      : charge.amount;
  for (final r in s.current.where(
    (r) => r.id != excluding && r.values['debt'] == charge.values['debt'],
  )) {
    if ([
      'debtPayment',
      'debtClassification',
      'debtPayoff',
    ].contains(financeType(r))) {
      final reduction = parsePhp(r.values['reduction'] ?? '0.00'),
          principal = parsePhp(
            r.values['debtComponentContract'] == '1' &&
                    r.values['principalReduction']?.isNotEmpty == true
                ? r.values['principalReduction']!
                : '0.00',
          ),
          sources = debtAllocations(
            r.values['debtComponentContract'] == '1'
                ? r.values['reductionSources'] ?? ''
                : '',
          );
      if (r.date.compareTo(charge.date) >= 0 &&
          reduction > principal + sumMinor(sources.values)) {
        return null;
      }
      remaining -= sources[charge.id] ?? BigInt.zero;
    }
    if (financeType(r) == 'debtAdjustment' &&
        [
          'recognized_waiver',
          'rounding_waiver',
        ].contains(r.values['adjustmentKind']) &&
        r.values['chargeSource'] == charge.id) {
      remaining -= r.amount;
    }
  }
  return remaining;
}

void validateDebtReductionSources(FinanceRuleContext c, LocalRevision debt) {
  if (c.value('debtComponentContract') != '1') return;
  if (c.value('principalReduction').isEmpty &&
      c.value('reductionSources').isEmpty) {
    return;
  }
  final principal = c.value('principalReduction').isEmpty
          ? BigInt.zero
          : c.money('principalReduction', zero: true),
      sources = debtAllocations(c.value('reductionSources')),
      reduction = c.money('reduction', zero: true);
  if (principal + sumMinor(sources.values) != reduction) {
    reject(
      'Principal and charges must add up to the amount that lowers what you owe. Leave both blank if you don’t know.',
    );
  }
  final range = debtPrincipalRange(
    c.s,
    debt,
    '9999-12-31',
    excluding: c.old?.id,
  );
  if (principal > BigInt.zero && (range == null || principal > range.$1)) {
    reject(
      'That’s more principal than is left on this debt. Break down any earlier payments first.',
    );
  }
  for (final entry in sources.entries) {
    final charge = financeSource(c.s, entry.key, {
          'debtAdjustment',
          'borrowing',
        }),
        available = debtChargeRemaining(c.s, charge, excluding: c.old?.id);
    if (charge.values['debt'] != debt.actionId ||
        charge.date.compareTo(c.date) > 0 ||
        !recognizedDebtCharge(charge) ||
        available == null ||
        entry.value > available) {
      reject('That’s more than is left unpaid on that charge.');
    }
  }
}

void validateDebtProjection(FinanceRuleContext c) {
  final debt = c.v['debt'];
  if (debt == null) return;
  if (c.operation != 'debtAdjustment' &&
      c.v['debtComponentContract'] != '1' &&
      !c.s.current.any(
        (r) =>
            r.values['debt'] == debt &&
            (r.values['debtComponentContract'] == '1' ||
                financeType(r) == 'debtAdjustment'),
      )) {
    return;
  }
  final postings =
      [
            ...c.s.current
                .where((r) => r.id != c.old?.id && r.values['debt'] == debt)
                .expand((r) => r.postings),
            ...c.posts,
          ]
          .where((p) => ['debt_liability', 'debt_clearing'].contains(p.ledger))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  var liability = BigInt.zero, clearing = BigInt.zero;
  for (var i = 0; i < postings.length; i++) {
    final p = postings[i];
    if (p.ledger == 'debt_liability') {
      liability += p.amount;
    } else {
      clearing += p.amount;
    }
    if (i + 1 == postings.length || postings[i + 1].date != p.date) {
      if (liability > BigInt.zero || clearing < BigInt.zero) {
        reject(
          'This would lower what you owe by more than you owed on that date.',
        );
      }
    }
  }
  final closed =
      c.operation == 'debtPayoff' && c.command.kind != 'financeReversal' ||
      c.s.current.any(
        (r) =>
            r.id != c.old?.id &&
            financeType(r) == 'debtPayoff' &&
            r.values['debt'] == debt,
      );
  if (closed && (liability != BigInt.zero || clearing != BigInt.zero)) {
    reject(
      'This debt’s payoff wouldn’t add up after this change. Reverse the payoff first.',
    );
  }
}

Map<String, BigInt> debtAllocations(String input) {
  if (input.trim().isEmpty) return {};
  final rows = input.trim().split('\n');
  if (rows.length > 120) reject('A payment can cover at most 120 due dates.');
  final result = <String, BigInt>{};
  for (final row in rows) {
    final pair = row.split(',').map((s) => s.trim()).toList();
    if (pair.length != 2 || pair[0].isEmpty || result.containsKey(pair[0])) {
      reject('Each due date can appear only once.');
    }
    result[pair[0]] = component(parsePhp(pair[1]), positive: true);
  }
  return result;
}

const debtScheduleFrequencies = {'weekly', 'monthly', 'yearly', 'custom'};

/// How installment amounts were chosen: the same each time, a total divided
/// evenly, or a different amount for each payment.
const debtSplitModes = {'equal', 'divide', 'varied'};
const debtDueSoonDays = 7;

/// Optional descriptive cadence on a debt schedule. The explicit rows remain the
/// authority for dates, amounts and allocations; legacy schedules have none.
void validateDebtCadence(FinanceRuleContext c, List<FinanceScheduleRow> rows) {
  final frequency = c.value('frequency');
  if (frequency.isEmpty) {
    if ([
      'firstDue',
      'intervalDays',
      'installmentAmount',
      'splitMode',
    ].any((k) => c.value(k).isNotEmpty)) {
      reject('Choose how often you pay.');
    }
    return;
  }
  if (!debtScheduleFrequencies.contains(frequency)) {
    reject('Choose weekly, monthly, yearly or custom.');
  }
  if (c.value('firstDue').isEmpty) {
    reject('Enter the date of your first payment.');
  }
  if (civilDate(c.value('firstDue')) != rows.first.date) {
    reject('The first due date must match the first payment in the schedule.');
  }
  if (frequency == 'custom') {
    debtIntervalDays(c.value('intervalDays'));
  } else if (c.value('intervalDays').isNotEmpty) {
    reject('Days between payments only apply to a custom schedule.');
  }
  if (c.value('installmentAmount').isNotEmpty) c.money('installmentAmount');
  final split = c.value('splitMode');
  if (split.isNotEmpty && !debtSplitModes.contains(split)) {
    reject('Choose how the payments are split.');
  }
  if (split == 'varied' && c.value('installmentAmount').isNotEmpty) {
    reject('Payments of different amounts can’t have one payment amount.');
  }
}

int debtIntervalDays(String input) {
  final days = RegExp(r'^\d{1,4}$').hasMatch(input) ? int.parse(input) : 0;
  if (days < 1 || days > 3660) {
    reject('Enter a whole number of days from 1 to 3660.');
  }
  return days;
}

/// Date-only due date of occurrence [index] (0 is the anchor). Every occurrence
/// is derived from the anchor, so month-end clamping never drifts.
String debtOccurrence(
  String anchor,
  String frequency,
  int index, {
  String intervalDays = '',
}) {
  final a = DateTime.parse('${civilDate(anchor)}T00:00:00Z');
  if (index < 0) reject('Payments start on the first due date.');
  DateTime monthsLater(int months) {
    final last = DateTime.utc(a.year, a.month + months + 1, 0).day;
    return DateTime.utc(a.year, a.month + months, a.day > last ? last : a.day);
  }

  final day = switch (frequency) {
    'weekly' => a.add(Duration(days: 7 * index)),
    'monthly' => monthsLater(index),
    'yearly' => monthsLater(12 * index),
    'custom' => a.add(Duration(days: debtIntervalDays(intervalDays) * index)),
    _ => reject('Choose weekly, monthly, yearly or custom.'),
  };
  return civilDate(day.toIso8601String().substring(0, 10));
}

/// Splits [total] evenly; any leftover centavos go on the final payment.
List<BigInt> debtSplitAmounts(BigInt total, int count) {
  if (count < 1 || count > 120) reject('Use 1 to 120 payments.');
  final each = total ~/ BigInt.from(count);
  if (each <= BigInt.zero || total > maxComponent) {
    reject('That amount is too small to split into that many payments.');
  }
  return [
    for (var i = 0; i < count; i++)
      i == count - 1 ? total - each * BigInt.from(count - 1) : each,
  ];
}

/// Explicit rows for review before saving, one amount per payment; never saved
/// implicitly. Labels and dates come from the cadence.
String debtScheduleRows({
  required String firstDue,
  required String frequency,
  required List<BigInt> amounts,
  String intervalDays = '',
}) {
  if (amounts.isEmpty || amounts.length > 120) {
    reject('Use 1 to 120 payments.');
  }
  for (final amount in amounts) {
    if (amount <= BigInt.zero || amount > maxComponent) {
      reject('Enter an amount above zero for every payment.');
    }
  }
  return [
    for (var i = 0; i < amounts.length; i++)
      'Installment ${i + 1},${debtOccurrence(firstDue, frequency, i, intervalDays: intervalDays)},${phpDecimal(amounts[i])}',
  ].join('\n');
}

/// The same amount for [count] payments.
String debtCadenceRows({
  required String firstDue,
  required String frequency,
  required String installmentAmount,
  required int count,
  String intervalDays = '',
}) {
  if (count < 1 || count > 120) reject('Use 1 to 120 payments.');
  return debtScheduleRows(
    firstDue: firstDue,
    frequency: frequency,
    amounts: List.filled(count, parsePhp(installmentAmount)),
    intervalDays: intervalDays,
  );
}

enum DebtDueStatus {
  overdue('Overdue'),
  dueToday('Due today'),
  dueSoon('Due soon'),
  upcoming('Upcoming'),
  scheduleNotSet('Schedule not set');

  const DebtDueStatus(this.label);
  final String label;
}

DebtDueStatus debtDueStatus(
  String? due,
  String today, {
  int soonDays = debtDueSoonDays,
}) {
  if (due == null) return DebtDueStatus.scheduleNotSet;
  final days = DateTime.parse('${civilDate(due)}T00:00:00Z')
      .difference(DateTime.parse('${civilDate(today)}T00:00:00Z'))
      .inDays;
  return days < 0
      ? DebtDueStatus.overdue
      : days == 0
      ? DebtDueStatus.dueToday
      : days <= soonDays
      ? DebtDueStatus.dueSoon
      : DebtDueStatus.upcoming;
}

/// Historical paid amount plus explicit due allocations from actual payments
/// on any revision of [schedule]. Unapplied money satisfies no installment.
BigInt debtInstallmentPaid(
  LocalSnapshot s,
  LocalRevision schedule,
  FinanceScheduleRow row,
  String through,
) =>
    row.paid +
    sumMinor(
      s.current
          .where(
            (r) =>
                financeType(r) == 'debtPayment' &&
                r.date.compareTo(through) <= 0 &&
                (r.values['scheduleSource'] ?? '').isNotEmpty &&
                s.revision(r.values['scheduleSource']!).actionId ==
                    schedule.actionId,
          )
          .map(
            (r) =>
                debtAllocations(r.values['allocations'] ?? '')[row.id] ??
                BigInt.zero,
          ),
    );

class DebtDueSummary {
  const DebtDueSummary(
    this.schedule,
    this.open,
    this.today,
    this.soonDays, {
    this.closed = false,
  });
  final LocalRevision? schedule;

  /// A provider payoff cancels every remaining installment.
  final bool closed;

  /// Unsatisfied installments in due order with their remaining amounts.
  final List<(FinanceScheduleRow, BigInt)> open;
  final String today;
  final int soonDays;
  (FinanceScheduleRow, BigInt)? get next => open.firstOrNull;

  /// Last contractual row; not a provider maturity or payoff date.
  String? get finalScheduledDue => schedule == null
      ? null
      : financeSchedule(schedule!.values['schedule']!).last.date;
  Iterable<(FinanceScheduleRow, BigInt)> get overdue =>
      open.where((o) => o.$1.date.compareTo(today) < 0);
  BigInt get overdueAmount => sumMinor(overdue.map((o) => o.$2));

  /// Each payment has its own amount, so the next one should be confirmed.
  bool get amountsVary => schedule?.values['splitMode'] == 'varied';

  /// Calendar days from today to the next installment; negative when overdue.
  int? get daysUntilNext => next == null
      ? null
      : DateTime.parse('${next!.$1.date}T00:00:00Z')
            .difference(DateTime.parse('${today}T00:00:00Z'))
            .inDays;

  /// Overdue first, then due today, upcoming/soon by date, unscheduled, and
  /// finally settled or closed debts.
  int get urgencyRank => switch (status) {
    DebtDueStatus.overdue => 0,
    DebtDueStatus.dueToday => 1,
    DebtDueStatus.dueSoon || DebtDueStatus.upcoming => 2,
    DebtDueStatus.scheduleNotSet => 3,
    null => 4,
  };

  /// Null when a schedule exists but nothing remains (satisfied or closed).
  DebtDueStatus? get status => schedule == null
      ? DebtDueStatus.scheduleNotSet
      : next == null
      ? null
      : debtDueStatus(next!.$1.date, today, soonDays: soonDays);
}

DebtDueSummary debtDueSummary(
  LocalSnapshot s,
  LocalRevision debt,
  String today, {
  int soonDays = debtDueSoonDays,
}) {
  final schedule = s.current
      .where(
        (r) =>
            financeType(r) == 'debtSchedule' &&
            r.values['debt'] == debt.actionId,
      )
      .firstOrNull;
  if (schedule == null) return DebtDueSummary(null, const [], today, soonDays);
  final closed = s.current.any(
    (r) =>
        financeType(r) == 'debtPayoff' &&
        r.date.compareTo(today) <= 0 &&
        r.values['debt'] == debt.actionId,
  );
  return DebtDueSummary(
    schedule,
    [
      if (!closed)
        for (final row in financeSchedule(schedule.values['schedule']!))
          if (row.amount > debtInstallmentPaid(s, schedule, row, today))
            (row, row.amount - debtInstallmentPaid(s, schedule, row, today)),
    ],
    today,
    soonDays,
    closed: closed,
  );
}

/// Urgency ordering: most overdue first, then nearest due date.
int compareDebtUrgency(DebtDueSummary a, DebtDueSummary b) {
  final byRank = a.urgencyRank.compareTo(b.urgencyRank);
  if (byRank != 0 || a.next == null || b.next == null) return byRank;
  return a.next!.$1.date.compareTo(b.next!.$1.date);
}
