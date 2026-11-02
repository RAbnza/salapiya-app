part of '../local/finance_domain.dart';

void planCard(FinanceRuleContext c) {
  final s = c.s, v = c.v, op = c.operation;
  if (op == 'creditCard') {
    c.text('issuer', max: 200);
    if (c.value('limit').isNotEmpty) c.money('limit', zero: true, wide: true);
    if (s.current.any(
      (r) =>
          r.id != c.old?.id &&
          financeType(r) == 'creditCard' &&
          r.title.toLowerCase() == c.title.toLowerCase(),
    )) {
      reject('You already have a card with this name.');
    }
    v['card'] = c.old?.actionId ?? c.command.id;
    c.total = c.money('amount', zero: true, signed: true);
    c.post('card_liability', -c.total);
    c.post('equity', c.total);
    return;
  }
  final card = c.ref('card', {'creditCard'});
  v['card'] = card.actionId;
  if (c.date.compareTo(card.date) < 0) {
    reject('Choose a date on or after the day this card starts in Salapiya.');
  }
  switch (op) {
    case 'cardAuthorization':
      c.total = c.money('amount');
      c.text('reference');
      c.effects.add(
        'A pending charge. It doesn’t count as spending or in what you owe yet.',
      );
    case 'cardPurchase':
    case 'cardFee':
    case 'cardInterest':
      final posted = civilDate(c.text('postingDate'));
      if (posted.compareTo(c.date) < 0) {
        reject('The date it posted can’t be before the purchase date.');
      }
      c.total = c.money('amount');
      c.kind = 'expense';
      c.post('card_liability', -c.total);
      if (c.value('split') == 'true') {
        final count = int.tryParse(c.value('splitCount')) ?? 2;
        if (count < 2 || count > 100) reject('Split this into 2 to 100 parts.');
        var allocated = c.money('splitAmount');
        c.expense(allocated);
        for (var i = 2; i < count; i++) {
          final part = c.money('split${i}Amount');
          allocated += part;
          c.expense(part, key: 'split${i}Category');
        }
        if (allocated >= c.total) {
          reject(
            'The splits must add up to less than the total, so something is left for the last category.',
          );
        }
        c.expense(c.total - allocated, key: 'splitCategory');
      } else {
        c.expense(c.total);
      }
      if (c.value('authorization').isNotEmpty) {
        final auth = c.ref('authorization', {'cardAuthorization'});
        if (auth.values['card'] != card.actionId ||
            s.current.any(
              (r) => r.id != c.old?.id && r.values['authorization'] == auth.id,
            )) {
          reject(
            'That pending charge was already used, or it’s on another card.',
          );
        }
        c.source = auth.id;
      }
      c.effects.add(
        'Spending counts on the purchase date. It posted on $posted. No cash moves.',
      );
    case 'cardPayment':
      c.total = c.money('amount');
      c.cash(-c.total);
      c.post('card_liability', c.total);
      c.effects.add(
        'This isn’t new spending. Anything above what you owe becomes card credit, which isn’t cash.',
      );
    case 'cardRefund':
      final purchase = c.ref('purchase', {'cardPurchase'});
      if (purchase.values['card'] != card.actionId ||
          purchase.date.compareTo(c.date) > 0) {
        reject(
          'Choose a purchase on this card, dated on or before the refund. A shared purchase is refunded in Shared Expenses.',
        );
      }
      c.total = c.money('amount');
      final category = c.text('category');
      final sharedPurchase = purchase.values.containsKey('sharedGroup');
      final available = sharedPurchase
          ? parsePhp(purchase.values['fundingAmount']!)
          : sumMinor(
              purchase.postings
                  .where((p) => p.ledger == 'expense' && p.category == category)
                  .map((p) => p.amount),
            );
      final used = sumMinor(
        s.current
            .where(
              (r) =>
                  r.id != c.old?.id &&
                  financeType(r) == 'cardRefund' &&
                  r.values['purchase'] == purchase.id &&
                  (sharedPurchase || r.values['category'] == category),
            )
            .map(
              (r) => r.values['fundingAmount'] == null
                  ? r.amount
                  : parsePhp(r.values['fundingAmount']!),
            ),
      );
      if (c.total + used > available) {
        reject('That’s more than is left to refund in this category.');
      }
      c.text('reason');
      c.kind = 'refund';
      c.source = purchase.id;
      c.post('card_liability', c.total);
      if (sharedPurchase) {
        c.post('shared_clearing', -c.total);
        c.effects.add(
          'The card credit waits until you apply it in Shared Expenses.',
        );
      } else {
        c.expense(-c.total);
      }
    case 'statement':
      final start = civilDate(c.text('start')),
          end = civilDate(c.text('end')),
          issued = civilDate(c.text('issued')),
          due = civilDate(c.text('due'));
      if (start.compareTo(end) > 0 ||
          end.compareTo(issued) > 0 ||
          issued.compareTo(due) > 0) {
        reject(
          'Check the dates: the period ends by the statement date, and the due date comes last.',
        );
      }
      c.total = c.money('amount', zero: true, signed: true);
      if (c.value('minimum').isNotEmpty) {
        final minimum = c.money('minimum', zero: true);
        if (minimum > (c.total > BigInt.zero ? c.total : BigInt.zero)) {
          reject('The minimum due can’t be more than the statement balance.');
        }
      }
      c.text('reference');
      if (c.value('verified') != 'true') {
        reject('Confirm this matches your statement.');
      }
    case 'statementLink':
      final statement = c.ref('statement', {'statement'});
      final activity = c.ref('activity', {
        'cardPurchase',
        'cardPayment',
        'cardFee',
        'cardInterest',
        'cardRefund',
      });
      if (statement.values['card'] != card.actionId ||
          activity.values['card'] != card.actionId ||
          s.current.any(
            (r) =>
                r.id != c.old?.id &&
                financeType(r) == op &&
                r.values['activity'] == activity.id,
          )) {
        reject(
          'Choose activity on this card that isn’t already matched to a statement.',
        );
      }
      if (c.value('verified') != 'true') {
        reject(
          'Confirm this is on the statement. Dates alone can’t show that.',
        );
      }
      c.source = activity.id;
    case 'cardAllocation':
      final statement = c.ref('statement', {'statement'});
      final payment = c.ref('payment', {'cardPayment', 'cardRefund'});
      if (statement.values['card'] != card.actionId ||
          payment.values['card'] != card.actionId ||
          payment.date.compareTo(c.date) > 0 ||
          statement.values['issued']!.compareTo(c.date) > 0) {
        reject(
          'Choose a statement and a payment on this card. The date can’t be before either of them.',
        );
      }
      c.total = c.money('amount');
      if (c.total + c.used(op, 'payment', payment.id) > payment.amount ||
          c.total + c.used(op, 'statement', statement.id) > statement.amount) {
        reject(
          'That’s more than is left on this payment or still due on this statement.',
        );
      }
      if (c.value('verified') != 'true') {
        reject('Confirm your card issuer applied it this way.');
      }
      c.source = payment.id;
    case 'installment':
      final purchase = c.ref('purchase', {'cardPurchase'});
      if (purchase.values['card'] != card.actionId) {
        reject('Choose a purchase on this card.');
      }
      final rows = financeSchedule(c.text('schedule'));
      c.total = sumMinor(rows.map((r) => r.amount));
      if (c.value('principal').isNotEmpty ||
          c.value('interest').isNotEmpty ||
          c.value('fee').isNotEmpty) {
        if (['principal', 'interest', 'fee'].any((k) => c.value(k).isEmpty)) {
          reject(
            'Enter principal, interest and fee together, or leave all three blank.',
          );
        }
        if (sumMinor(
                  [
                    'principal',
                    'interest',
                    'fee',
                  ].map((k) => c.money(k, zero: true)),
                ) !=
                c.total ||
            c.money('principal', zero: true) >
                -sumMinor(
                  purchase.postings
                      .where((p) => p.ledger == 'card_liability')
                      .map((p) => p.amount),
                )) {
          reject(
            'Principal, interest and fee must add up to the plan’s total, and principal can’t be more than the purchase.',
          );
        }
      }
      if (s.current.any(
        (r) =>
            r.id != c.old?.id &&
            financeType(r) == op &&
            r.values['purchase'] == purchase.id,
      )) {
        reject('This purchase already has an installment plan.');
      }
      if (c.value('verified') != 'true') {
        reject(
          'Confirm these dates and amounts match your card issuer’s plan.',
        );
      }
      c.text('reference');
      c.source = purchase.id;
    case 'installmentApplication':
      final plan = c.ref('plan', {'installment'});
      final allocation = c.ref('payment', {'cardAllocation'});
      final statement = financeSource(s, allocation.values['statement']!, {
        'statement',
      });
      if (plan.values['card'] != card.actionId ||
          statement.values['card'] != card.actionId) {
        reject('Choose a plan and a matched payment on this card.');
      }
      final row = financeSchedule(plan.values['schedule']!)
          .where((r) => r.id == c.value('row'))
          .firstOrNull;
      if (row == null) reject('Choose a payment in this plan.');
      c.total = c.money('amount');
      final usedRow = sumMinor(
        s.current
            .where(
              (r) =>
                  r.id != c.old?.id &&
                  financeType(r) == op &&
                  r.values['plan'] == plan.id &&
                  r.values['row'] == row.id,
            )
            .map((r) => r.amount),
      );
      if (c.total + usedRow + row.paid > row.amount ||
          c.total + c.used(op, 'payment', allocation.id) > allocation.amount) {
        reject(
          'That’s more than is left on this installment or on the matched payment.',
        );
      }
      if (c.value('verified') != 'true') {
        reject('Confirm your card issuer applied it this way.');
      }
      c.source = allocation.id;
    default:
      reject('Unsupported native financial operation.');
  }
}

class FinanceScheduleRow {
  const FinanceScheduleRow(this.id, this.date, this.amount, this.paid);
  final String id, date;
  final BigInt amount, paid;
}

/// Explicit provider rows: stable-label,date,PHP amount[,historically paid PHP].
List<FinanceScheduleRow> financeSchedule(String input) {
  final lines = input.trim().split('\n');
  if (lines.isEmpty || lines.length > 120) {
    reject('Enter 1 to 120 payments.');
  }
  final seen = <String>{};
  final result = <FinanceScheduleRow>[];
  String? previous;
  for (final line in lines) {
    final cells = line.split(',').map((v) => v.trim()).toList();
    if (cells.length < 3 ||
        cells.length > 4 ||
        cells[0].isEmpty ||
        cells[0].length > 100 ||
        !seen.add(cells[0])) {
      reject(
        'Put each payment on its own line: a name used once, the date, the amount and, if any, what’s already paid.',
      );
    }
    final date = civilDate(cells[1]);
    if (previous != null && date.compareTo(previous) < 0) {
      reject('List the payments in date order.');
    }
    previous = date;
    final amount = component(parsePhp(cells[2]), positive: true);
    final paid = cells.length == 4 ? parsePhp(cells[3]) : BigInt.zero;
    if (paid > amount) {
      reject('What’s already paid can’t be more than the payment.');
    }
    result.add(FinanceScheduleRow(cells[0], date, amount, paid));
  }
  return result;
}
