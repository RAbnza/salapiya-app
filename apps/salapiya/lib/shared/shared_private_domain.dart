part of '../local/finance_domain.dart';

// P3 extends the established private command, immutable revision and journal
// contract. It never accepts a client-supplied posting plan or another owner.
bool sharedSourceUsesCard(LocalRevision? source) =>
    source != null &&
    ['cardPurchase', 'cardRefund'].contains(financeType(source));

LocalPlan planSharedPrivate(LocalSnapshot s, LocalCommand cmd) {
  final v = Map<String, String>.from(cmd.values);
  String value(String k) => v[k] ?? '';
  final mode = value('sharedMode'), date = civilDate(value('date'));
  final group = value('sharedGroup'), sourceKey = value('sharedKey');
  if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(group) ||
      !RegExp(r'^[0-9a-f-]{36}$').hasMatch(sourceKey) ||
      value('sharedRevision').isEmpty) {
    reject('A versioned group source is required.');
  }
  final cardFunded = value('funding') == 'card';
  if (cardFunded && !['bill', 'refund'].contains(mode)) {
    reject('Payments need a cash or bank account, not a card.');
  }
  BigInt amount(String k) {
    final n = parsePhp(value(k));
    return n == BigInt.zero ? n : component(n, positive: false);
  }

  final paid = amount('fundingAmount'), share = amount('shareAmount');
  final oldId = value('source');
  LocalRevision? old;
  if (oldId.isNotEmpty) {
    old = s.revision(oldId);
    if (!s.current.contains(old) || value('sourceVersion') != '${old.number}') {
      reject('Your record changed. Check it and try again.');
    }
    if (value('reason').trim().isEmpty) {
      reject('Say why you’re changing your record.');
    }
    final dependencies = s.current
        .where((r) => r.source == oldId && financeType(r) != 'financialFile')
        .toList();
    final restoredPayment =
        mode == 'payment' &&
        dependencies.every(
          (r) =>
              r.values['sharedMode'] == 'clear' &&
              s.current.any(
                (u) => u.source == r.id && u.values['sharedMode'] == 'unclear',
              ),
        );
    if (dependencies.isNotEmpty && !restoredPayment) {
      reject('Something else in your records depends on this. Fix that first.');
    }
  }
  if (s.current.any(
    (r) =>
        r.id != oldId &&
        r.values['sharedGroup'] == group &&
        r.values['sharedKey'] == sourceKey &&
        r.values['sharedMode'] == mode,
  )) {
    reject('This is already in your Money. Open it to check it.');
  }
  if (!['bill', 'payment', 'refund', 'clear', 'unclear'].contains(mode)) {
    reject('Unsupported private group effect.');
  }
  final posts = <LocalPosting>[];
  void post(String ledger, BigInt n, {String? account, String? category}) {
    if (n != BigInt.zero) {
      component(n);
      posts.add(
        LocalPosting(ledger, n, date, account: account, category: category),
      );
    }
  }

  void cash(BigInt n) {
    if (n == BigInt.zero) return;
    final account = s.account(value('account'));
    if (account.archived || date.compareTo(account.cutoff) <= 0) {
      reject(
        'Choose an active account whose starting balance is dated before this.',
      );
    }
    post('cash', n, account: account.id);
  }

  void expense(BigInt n) {
    if (n != BigInt.zero) {
      s.category(value('category'), 'expense');
      post('expense', n, category: value('category'));
    }
  }

  void position(BigInt n) {
    post(n >= BigInt.zero ? 'shared_receivable' : 'shared_payable', n);
  }

  void offsetPosition(BigInt n) {
    if (value('sharedAccounting') != '2') {
      position(n);
      return;
    }
    final existing = s.current
        .where((r) => r.id != oldId && r.values['sharedGroup'] == group)
        .expand((r) => r.postings);
    final payable = sumMinor(
      existing.where((p) => p.ledger == 'shared_payable').map((p) => p.amount),
    );
    final receivable = sumMinor(
      existing
          .where((p) => p.ledger == 'shared_receivable')
          .map((p) => p.amount),
    );
    final payableAvailable = payable < BigInt.zero ? -payable : BigInt.zero,
        receivableAvailable = receivable > BigInt.zero
            ? receivable
            : BigInt.zero;
    final payableDelta = n > BigInt.zero
        ? (n < payableAvailable ? n : payableAvailable)
        : n < BigInt.zero
        ? n + (-n < receivableAvailable ? -n : receivableAvailable)
        : BigInt.zero;
    post('shared_payable', payableDelta);
    post('shared_receivable', n - payableDelta);
  }

  var kind = 'expense', total = paid;
  if (cardFunded) {
    if (old == null || !sharedSourceUsesCard(old)) {
      reject(
        'Log the card purchase or refund in Money first, then add it here.',
      );
    }
    final card = financeSource(s, old.values['card'] ?? '', {'creditCard'});
    final recognizedCardMovement = sumMinor(
      old.postings
          .where((p) => p.ledger == 'card_liability')
          .map((p) => p.amount),
    );
    if (recognizedCardMovement != (mode == 'bill' ? -paid : paid)) {
      reject('That doesn’t match your card record. Use its amount.');
    }
    if (value('card') != card.actionId ||
        old.date != date ||
        (mode == 'bill' &&
            (financeType(old) != 'cardPurchase' ||
                (old.values['sharedGroup'] == null
                    ? old.amount != paid
                    : parsePhp(old.values['fundingAmount']!) != paid))) ||
        (mode == 'refund' &&
            (financeType(old) != 'cardRefund' ||
                (old.values['sharedGroup'] == null
                    ? old.amount != paid
                    : parsePhp(old.values['fundingAmount']!) != paid)))) {
      reject('Keep the card, amount and date from your card record.');
    }
    v.addAll({
      'card': card.actionId,
      'financeType': financeType(old),
      'financeContract': '1',
      'postingDate': old.values['postingDate'] ?? old.date,
    });
    v['account'] = old.values['account'] ?? '';
    if (mode == 'refund') v['purchase'] = old.values['purchase']!;
  }
  if (mode == 'bill') {
    if (old != null) {
      if (old.values['sharedGroup'] == null) {
        if (old.kind != 'expense' ||
            old.amount != paid ||
            old.date != date ||
            old.values['split'] == 'true' ||
            (!cardFunded && old.values['account'] != value('account'))) {
          reject('Keep the amount, date and account from your saved purchase.');
        }
      } else if (old.values['sharedGroup'] != group ||
          old.values['sharedKey'] != sourceKey) {
        reject(
          'This record is linked to another bill, so it can’t be used here.',
        );
      } else if (value('acknowledgeFunding') != 'true' &&
          (old.values['fundingAmount'] != value('fundingAmount') ||
              old.values['account'] != value('account'))) {
        reject('You’re changing what you paid. Confirm that’s right.');
      }
    }
    if (cardFunded) {
      post('card_liability', -paid);
    } else {
      cash(-paid);
    }
    expense(share);
    position(paid - share);
    total = share;
  } else if (mode == 'payment') {
    if (paid == BigInt.zero || share != BigInt.zero) {
      reject(
        'A payment needs an amount, and none of it counts as your spending.',
      );
    }
    final outgoing = value('direction') == 'out';
    if (!outgoing && value('direction') != 'in') {
      reject('Choose actual payment direction.');
    }
    if (old != null &&
        (old.values['sharedMode'] != 'payment' ||
            old.values['sharedGroup'] != group ||
            old.values['sharedKey'] == sourceKey ||
            old.values['fundingAmount'] != value('fundingAmount') ||
            old.values['direction'] != value('direction') ||
            old.values['account'] != value('account') ||
            old.date != date)) {
      reject(
        'To reuse that record, the group, people, date, account and amount must all match.',
      );
    }
    cash(outgoing ? -paid : paid);
    post('shared_clearing', outgoing ? paid : -paid);
    kind = 'adjustment';
  } else if (mode == 'refund') {
    if (cardFunded) {
      post('card_liability', paid);
    } else {
      cash(paid);
    }
    final adopted = s.current.any(
      (r) =>
          r.values['sharedMode'] == 'bill' &&
          r.values['sharedGroup'] == group &&
          r.values['sharedKey'] == value('billSource') &&
          r.values['sharedRevision'] == value('billRevision'),
    );
    if (value('coverage') != (adopted ? 'adopted' : 'clearing')) {
      reject(
        'This bill’s place in your Money changed. Check it and try again.',
      );
    }
    if (adopted) {
      expense(-share);
      offsetPosition(share - paid);
    } else {
      post('shared_clearing', -paid);
    }
    kind = 'refund';
    total = adopted ? share : BigInt.zero;
  } else if (mode == 'unclear') {
    if (old != null || paid == BigInt.zero || share != BigInt.zero) {
      reject(
        'This can’t be taken out of your group balance with these amounts.',
      );
    }
    final clearing = s.revision(value('paymentSource'));
    if (!s.current.contains(clearing) ||
        clearing.values['sharedMode'] != 'clear' ||
        clearing.values['sharedGroup'] != group ||
        clearing.values['sharedKey'] != sourceKey ||
        clearing.values['fundingAmount'] != value('fundingAmount') ||
        s.current.any((r) => r.source == clearing.id)) {
      reject(
        'This was already taken out of your group balance, or it changed.',
      );
    }
    final outgoing = clearing.values['direction'] == 'out';
    if (value('sharedAccounting') == '2') {
      for (final p in clearing.postings) {
        post(p.ledger, -p.amount);
      }
    } else {
      post('shared_clearing', outgoing ? paid : -paid);
      post(
        outgoing ? 'shared_payable' : 'shared_receivable',
        outgoing ? -paid : paid,
      );
    }
    kind = 'adjustment';
  } else {
    if (old != null || paid == BigInt.zero || share != BigInt.zero) {
      reject('This can’t be counted in your group balance with these amounts.');
    }
    final payment = s.revision(value('paymentSource'));
    if (!s.current.contains(payment) ||
        payment.values['sharedMode'] != 'payment' ||
        payment.values['sharedGroup'] != group ||
        payment.values['sharedKey'] != sourceKey ||
        payment.values['fundingAmount'] != value('fundingAmount') ||
        s.current.any((r) => r.source == payment.id)) {
      reject('This was already counted in your group balance, or it changed.');
    }
    final outgoing = payment.values['direction'] == 'out';
    post('shared_clearing', outgoing ? -paid : paid);
    if (value('sharedAccounting') == '2') {
      offsetPosition(outgoing ? paid : -paid);
    } else {
      post(
        outgoing ? 'shared_payable' : 'shared_receivable',
        outgoing ? paid : -paid,
      );
    }
    kind = 'adjustment';
  }
  if (old != null &&
      mode == 'refund' &&
      !(cardFunded && old.values['sharedGroup'] == null) &&
      (old.values['sharedGroup'] != group ||
          old.values['sharedKey'] != sourceKey ||
          old.values['fundingAmount'] != value('fundingAmount') ||
          old.values['account'] != value('account'))) {
    reject('Keep the amount and account from your saved refund.');
  }
  if (old != null && !['bill', 'refund', 'payment'].contains(mode)) {
    reject(
      'Payment/refund cash corrections require their separate retained-evidence review.',
    );
  }
  final affected = posts
      .where((p) => p.account != null)
      .map((p) => p.account!)
      .toSet();
  for (final a in affected) {
    final proposed = [
      ...s.current
          .where((r) => r.id != oldId)
          .expand((r) => r.postings)
          .where((p) => p.account == a),
      ...posts.where((p) => p.account == a),
    ];
    var running = BigInt.zero;
    for (final day in proposed.map((p) => p.date).toSet().toList()..sort()) {
      running += sumMinor(
        proposed.where((p) => p.date == day).map((p) => p.amount),
      );
      sqliteInteger(running);
      if (day.compareTo(date) >= 0 &&
          running < BigInt.zero &&
          value('acknowledge') != 'true') {
        reject('This takes the account negative. Confirm that’s right.');
      }
    }
  }
  if (sumMinor(posts.map((p) => p.amount)) != BigInt.zero) {
    reject('Unbalanced private group effect.');
  }
  return LocalPlan(
    effects: [
      'Cash ₱${phpDecimal(sumMinor(posts.where((p) => p.ledger == 'cash').map((p) => p.amount)))}; your spending ₱${phpDecimal(sumMinor(posts.where((p) => p.ledger == 'expense').map((p) => p.amount)))}.',
      'Only your own records change. The group’s records and anyone’s confirmation stay as they are.',
    ],
    revision: LocalRevision(
      id: cmd.id,
      actionId: old?.actionId ?? cmd.id,
      kind: kind,
      change: old == null ? 'create' : 'replace',
      date: date,
      title: value('name'),
      amount: total,
      values: Map.of(v),
      postings: posts,
      number: (old?.number ?? 0) + 1,
      previous: old?.id,
      source: cardFunded && mode == 'refund'
          ? old?.source
          : ['clear', 'unclear'].contains(mode)
          ? value('paymentSource')
          : null,
    ),
  );
}
