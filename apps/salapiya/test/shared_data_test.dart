import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/shared/shared_data.dart';
import 'package:salapiya/shared/shared_demo.dart';
import 'package:salapiya/shared/shared_domain.dart';

const a = '10000000-0000-4000-8000-000000000001';
const b = '10000000-0000-4000-8000-000000000002';
const c = '10000000-0000-4000-8000-000000000003';
const today = '2026-10-31';

SharedJson revision(
  String id,
  String name,
  String date,
  String total,
  Map<String, String> paid,
  Map<String, String> shares, {
  String method = 'exact',
  String? reason,
}) => {
  'id': id,
  'name': name,
  'date': date,
  'total': total,
  'paid': paid,
  'shares': shares,
  'method': method,
  'reason': reason,
};

SharedJson person(String name, {String? user, bool active = true}) => {
  'name': name,
  'user': user,
  'kind': user == null ? 'manual' : 'registered',
  'active': active,
};

SharedGroup group({
  SharedJson bills = const {},
  SharedJson settlements = const {},
  SharedJson? people,
  bool complete = true,
  bool archived = false,
  String owner = a,
}) => SharedGroup({
  'id': 'g',
  'name': 'Group',
  'owner': owner,
  'version': 1,
  'complete': complete,
  'archived': archived,
  'people':
      people ??
      {
        a: person('Ana', user: 'me'),
        b: person('Ben', user: 'ben'),
        c: person('Cy', user: 'cy'),
      },
  'bills': bills,
  'settlements': settlements,
  'activity': const [],
});

SharedJson bill(
  List<SharedJson> revisions, {
  List<SharedJson> refunds = const [],
  String creator = a,
}) => {'creator': creator, 'revisions': revisions, 'refunds': refunds};

SharedJson payment(
  String sender,
  String recipient,
  String amount,
  String state, {
  SharedJson allocations = const {},
  String advance = '0',
  bool manual = false,
  String at = '2026-10-29 01:00:00+00',
  String date = '2026-10-29',
}) => {
  'sender': sender,
  'recipient': recipient,
  'amount': amount,
  'state': state,
  'date': date,
  'allocations': allocations,
  'advance': advance,
  'manual': manual,
  'events': [
    {'state': 'pending', 'at': at},
  ],
};

void main() {
  dataTests();
}

void dataTests() {
  final dinner = bill([
    revision(
      'r1',
      'Dinner',
      '2026-10-10',
      '30000',
      {a: '30000'},
      {a: '10000', b: '10000', c: '10000'},
      method: 'equal',
    ),
  ]);

  test('standing: empty, owed, owing and all square', () {
    expect(sharedStanding(group(), a).kind, StandingKind.square);
    final owed = sharedStanding(group(bills: {'x': dinner}), a);
    expect(owed.kind, StandingKind.owedToYou);
    expect(owed.amount, BigInt.from(20000));
    final owing = sharedStanding(group(bills: {'x': dinner}), b);
    expect(owing.kind, StandingKind.youOwe);
    expect(owing.amount, BigInt.from(10000));
  });

  test('a waiting payment changes only the labelled projection', () {
    final g = group(
      bills: {'x': dinner},
      settlements: {
        'p': payment(
          b,
          a,
          '4000',
          'pending',
          allocations: {
            'x': {'amount': '4000', 'revision': 'r1'},
          },
        ),
      },
    );
    final s = sharedStanding(g, a);
    expect(s.amount, BigInt.from(20000));
    expect(s.projected, BigInt.from(16000));
    expect(positionWords(s.projected!, (v) => '$v'), 'You’d be owed 16000');
  });

  test('a group the user left has no standing, and never throws', () {
    // A corrected bill names someone this person's copy doesn't list.
    final partial = group(
      complete: false,
      people: {a: person('Ana', user: 'me', active: false)},
      bills: {
        'x': bill([
          revision(
            'r1',
            'Moved out',
            '2026-07-01',
            '100',
            {c: '100'},
            {a: '50', c: '50'},
          ),
        ]),
      },
    );
    expect(sharedStanding(partial, a).kind, StandingKind.unknown);
    expect(pairsWithMe(partial, a), isEmpty);
    expect(sharedBillRows(partial, a).single.part, BigInt.from(50));
  });

  test('bills are newest first, after refunds, with the user’s part', () {
    final g = group(
      bills: {
        // UUID order isn't date order.
        'a-later': bill([
          revision('r2', 'Older', '2026-09-01', '100', {a: '100'}, {a: '100'}),
        ]),
        'z-first': bill(
          [
            revision(
              'r1',
              'Newer',
              '2026-10-20',
              '9000',
              {a: '9000'},
              {a: '3000', b: '3000', c: '3000'},
            ),
          ],
          refunds: [
            {
              'id': 'f',
              'total': '3000',
              'received': {a: '3000'},
              'credits': {a: '1000', b: '1000', c: '1000'},
            },
          ],
        ),
      },
    );
    final rows = sharedBillRows(g, a);
    expect(rows.map((r) => r.name), ['Newer', 'Older']);
    expect(rows.first.total, BigInt.from(6000));
    expect(rows.first.part, BigInt.from(2000));
    expect(rows.first.refunds, 1);
    // The list adds up to the rule's total.
    expect(rows.fold(BigInt.zero, (n, r) => n + r.total), g.spending);
  });

  test('what’s left per bill matches the rule’s due for everyone', () {
    final g = group(
      bills: {
        'x': dinner,
        'y': bill([
          revision(
            'r2',
            'Taxi',
            '2026-10-11',
            '6000',
            {b: '6000'},
            {a: '3000', b: '3000'},
          ),
        ]),
      },
    );
    for (final me in [a, b, c]) {
      final left = leftOnBills(g, me);
      for (final id in ['x', 'y']) {
        final due = [
          for (final other in [a, b, c])
            if (other != me) g.due(me, other, bill: id),
        ].fold(BigInt.zero, (n, v) => n + v);
        expect(left[id] ?? BigInt.zero, due, reason: '$me on $id');
      }
    }
  });

  test('who paid reads plainly, for one, two and many payers', () {
    final g = group();
    expect(paidBy(g, {a: '1', b: '0'}, a), 'You paid');
    expect(paidBy(g, {b: '1'}, a), 'Ben paid');
    expect(paidBy(g, {b: '1', a: '1'}, a), 'You and Ben paid');
    expect(paidBy(g, {a: '1', b: '1', c: '1'}, a), '3 people paid');
    expect(paidBy(g, {a: '0'}, a), 'Nobody paid');
  });

  test('a bill’s split follows the rule’s position, refunds included', () {
    final g = group(
      bills: {
        'x': bill(
          [
            revision(
              'r1',
              'Split',
              '2026-10-10',
              '9000',
              {a: '6000', b: '3000'},
              {a: '3000', b: '3000', c: '3000'},
            ),
          ],
          refunds: [
            {
              'id': 'f',
              'total': '1500',
              'received': {a: '1500'},
              'credits': {a: '500', b: '500', c: '500'},
            },
          ],
        ),
      },
    );
    final positions = g.billPositions('x');
    for (final row in billSplit(g, 'x', a)) {
      expect(row.position, positions[row.person]);
    }
    expect(billSplit(g, 'x', a).first.name, 'You');
  });

  test('the extra centavo is named only when there is one', () {
    final shares = equalShares(BigInt.from(10000), [c, a, b]);
    expect(extraCentavo({'method': 'equal', 'shares': shares}), [a]);
    expect(
      extraCentavo({
        'method': 'equal',
        'shares': equalShares(BigInt.from(9000), [a, b, c]),
      }),
      isEmpty,
    );
    expect(extraCentavo({'method': 'exact', 'shares': shares}), isEmpty);
  });

  test('month totals use the bill’s date, at both month edges', () {
    final rows = [
      SharedBillRow(
        id: '1',
        name: 'First',
        date: '2026-10-01',
        paidBy: '',
        total: BigInt.from(100),
        part: BigInt.from(40),
      ),
      SharedBillRow(
        id: '2',
        name: 'Last',
        date: '2026-10-31',
        paidBy: '',
        total: BigInt.from(200),
        part: BigInt.from(50),
      ),
      SharedBillRow(
        id: '3',
        name: 'Before',
        date: '2026-09-30',
        paidBy: '',
        total: BigInt.from(1000),
        part: BigInt.from(1),
      ),
      SharedBillRow(
        id: '4',
        name: 'Waiting',
        date: '2026-10-15',
        paidBy: '',
        total: BigInt.from(5000),
        part: BigInt.from(5),
        waiting: true,
      ),
    ];
    expect(monthTotal(rows, '2026-10'), BigInt.from(300));
    expect(monthPart(rows, '2026-10'), BigInt.from(90));
    final months = sharedByMonth(rows, '2026-10-31');
    expect(months.length, 6);
    expect(months.first.$1, '2026-05-01');
    expect(months.last.$2, BigInt.from(300));
    // Across a year end.
    expect(sharedByMonth(rows, '2026-01-15').first.$1, '2025-08-01');
  });

  test('a queued bill shows until the group has it', () {
    final g = group();
    final intent = {
      'id': 'q',
      'group_id': 'g',
      'state': 'pending',
      'payload':
          '{"op":"bill","values":{"name":"Cake","date":"2026-10-30","total":"900","paid":{"$a":"900"},"shares":{"$a":"900"},"method":"equal"}}',
    };
    final rows = sharedBillRows(g, a, intents: [intent]);
    expect(rows.single.waiting, isTrue);
    expect(rows.single.paidBy, 'You paid');
    expect(
      sharedBillRows(
        g,
        a,
        intents: [
          {...intent, 'state': 'reconciled'},
        ],
      ),
      isEmpty,
    );
  });

  test('payment roles, status and days waiting', () {
    final g = group(
      settlements: {
        'in': payment(b, a, '100', 'pending'),
        'out': payment(a, b, '200', 'pending'),
        'other': payment(b, c, '300', 'pending'),
        'done': payment(b, a, '400', 'confirmed', manual: true),
      },
    );
    final rows = {for (final r in sharedPaymentRows(g, a, today)) r.id: r};
    expect(rows['in']!.status, PaymentStatus.toConfirm);
    expect(rows['in']!.waitingDays, 2);
    expect(rows['out']!.status, PaymentStatus.waiting);
    expect(rows['out']!.role, PaymentRole.sender);
    expect(rows['other']!.role, PaymentRole.other);
    expect(rows['other']!.who, 'Ben → Cy');
    expect(rows['done']!.manual, isTrue);
    expect(rows['done']!.waitingDays, isNull);
  });

  test('days waiting use Manila’s calendar', () {
    expect(civilDayOf('2026-10-30 17:00:00+00'), '2026-10-31');
    expect(civilDayOf('2026-10-30 15:59:00+00'), '2026-10-30');
    expect(civilDayOf('not a time'), isNull);
    expect(civilDayOf(null), isNull);
  });

  paymentListTests();
  choiceTests();
  taskTests();
  wordTests();
  demoTests();
}

void paymentListTests() {
  final dinner = bill([
    revision(
      'r1',
      'Dinner',
      '2026-10-10',
      '30000',
      {a: '30000'},
      {a: '10000', b: '10000', c: '10000'},
    ),
  ]);

  test('filters put each payment under exactly one state', () {
    final g = group(
      bills: {'x': dinner},
      settlements: {
        'in': payment(b, a, '100', 'pending'),
        'out': payment(a, b, '200', 'pending'),
        'ok': payment(b, a, '300', 'confirmed'),
        'no': payment(b, a, '400', 'disputed'),
        'off': payment(b, a, '500', 'cancelled'),
        'back': payment(b, a, '600', 'reversed'),
      },
    );
    final rows = sharedPaymentRows(g, a, today);
    int count(PaymentFilter f) => rows.where(f.matches).length;
    expect(count(PaymentFilter.all), 6);
    expect(count(PaymentFilter.toConfirm), 1);
    expect(count(PaymentFilter.waiting), 1);
    expect(count(PaymentFilter.confirmed), 1);
    expect(count(PaymentFilter.disputed), 1);
    expect(count(PaymentFilter.closed), 2);
    expect(openPayments(rows).map((p) => p.id), ['in', 'out', 'no']);
    final (sum, n) = paymentTotal(rows.where((p) => p.id != 'back'));
    expect(sum, BigInt.from(1500));
    expect(n, 5);
  });

  test('what a payment was applied to reads plainly', () {
    SharedPaymentRow row(SharedJson applied, String ahead) => sharedPaymentRow(
      group(
        bills: {'x': dinner},
        settlements: {
          'p': payment(
            b,
            a,
            '100',
            'pending',
            allocations: applied,
            advance: ahead,
          ),
        },
      ),
      'p',
      a,
      today,
    );
    final g = group(bills: {'x': dinner});
    const one = {
      'x': {'amount': '100', 'revision': 'r1'},
    };
    const two = {
      'x': {'amount': '50', 'revision': 'r1'},
      'y': {'amount': '50', 'revision': 'r2'},
    };
    expect(appliedLine(g, row(one, '0')), 'Dinner');
    expect(appliedLine(g, row(one, '40')), 'Dinner + Paid ahead');
    expect(appliedLine(g, row(two, '0')), '2 bills');
    expect(appliedLine(g, row(const {}, '100')), 'Paid ahead');
    expect(appliedLine(g, row(const {}, '0')), '');
  });

  test('the projection is the sender’s view, and only ever labelled', () {
    final g = group(
      bills: {'x': dinner},
      settlements: {
        'p': payment(
          b,
          a,
          '4000',
          'pending',
          allocations: {
            'x': {'amount': '4000', 'revision': 'r1'},
          },
        ),
      },
    );
    final row = sharedPaymentRow(g, 'p', a, today);
    final (now, next) = paymentProjection(g, row)!;
    expect(now, BigInt.from(10000));
    expect(next, BigInt.from(6000));
    expect(paymentProjection(group(complete: false), row), isNull);
    expect(owedBetween(g, b, a), BigInt.from(10000));
    expect(owedBetween(g, a, b), BigInt.from(-10000));
  });

  test('a reversed payment doesn’t count, and a confirmed one does', () {
    SharedGroup state(String s) => group(
      bills: {'x': dinner},
      settlements: {
        'p': payment(
          b,
          a,
          '4000',
          s,
          allocations: {
            'x': {'amount': '4000', 'revision': 'r1'},
          },
        ),
      },
    );
    expect(sharedStanding(state('reversed'), b).amount, BigInt.from(10000));
    expect(sharedStanding(state('cancelled'), b).amount, BigInt.from(10000));
    expect(sharedStanding(state('disputed'), b).amount, BigInt.from(10000));
    expect(sharedStanding(state('confirmed'), b).amount, BigInt.from(6000));
  });

  test('a bill lists the payments applied to it, waiting ones included', () {
    final g = group(
      bills: {'x': dinner},
      settlements: {
        'p': payment(
          b,
          a,
          '4000',
          'pending',
          allocations: {
            'x': {'amount': '4000', 'revision': 'r1'},
          },
        ),
        'other': payment(b, a, '100', 'pending'),
      },
    );
    final rows = billPayments(g, 'x', a, today);
    expect(rows.single.$1.id, 'p');
    expect(rows.single.$2, BigInt.from(4000));
  });
}

void choiceTests() {
  test('what a payment offers matches the server, by role and state', () {
    final people = {
      a: person('Ana', user: 'me'),
      b: person('Ben', user: 'ben'),
      c: person('Lola'),
    };
    PaymentChoices choices(
      String sender,
      String recipient,
      String state,
      String me, {
      String owner = a,
    }) {
      final g = group(
        people: people,
        owner: owner,
        settlements: {'p': payment(sender, recipient, '100', state)},
      );
      return paymentChoices(g, 'p', me);
    }

    final recipient = choices(b, a, 'pending', a);
    expect(recipient.confirm, isTrue);
    expect(recipient.dispute, isTrue);
    expect(recipient.cancel, isFalse);
    expect(recipient.undo, isFalse);

    final sender = choices(a, b, 'pending', a);
    expect(sender.cancel, isTrue);
    expect(sender.confirm, isFalse);

    // A third party gets nothing.
    expect(choices(b, c, 'pending', a, owner: b).any, isFalse);
    // The owner answers for someone who isn't registered, and it says so.
    final manual = choices(b, c, 'pending', a);
    expect(manual.confirm, isTrue);
    expect(manual.manual, isTrue);
    // Only the recipient can undo, and only once it's confirmed.
    expect(choices(b, a, 'confirmed', a).undo, isTrue);
    expect(choices(b, a, 'confirmed', a).confirm, isFalse);
    expect(choices(a, b, 'disputed', a).cancel, isTrue);
    expect(choices(a, b, 'confirmed', a).cancel, isFalse);
    for (final closed in ['cancelled', 'reversed']) {
      expect(choices(b, a, closed, a).any, isFalse);
      expect(choices(a, b, closed, a).any, isFalse);
    }
  });

  test('only the bill’s creator changes it, and not when archived', () {
    final dinner = bill([
      revision('r', 'Dinner', '2026-10-10', '100', {a: '100'}, {a: '100'}),
    ]);
    expect(canChangeBill(group(bills: {'x': dinner}), 'x', a), isTrue);
    expect(canChangeBill(group(bills: {'x': dinner}), 'x', b), isFalse);
    expect(
      canChangeBill(group(bills: {'x': dinner}, archived: true), 'x', a),
      isFalse,
    );
    expect(canChangeBill(group(bills: {'x': dinner}), 'x', null), isFalse);
  });

  test('pairs with me add up to my position', () {
    final g = group(
      bills: {
        'x': bill([
          revision(
            'r1',
            'One',
            '2026-10-01',
            '30000',
            {a: '30000'},
            {a: '10000', b: '10000', c: '10000'},
          ),
        ]),
        'y': bill([
          revision(
            'r2',
            'Two',
            '2026-10-02',
            '6000',
            {b: '6000'},
            {a: '4000', b: '2000'},
          ),
        ]),
      },
    );
    final pairs = pairsWithMe(g, a);
    expect(pairs.fold(BigInt.zero, (n, p) => n + p.$2), g.positions()[a]);
    // Reciprocal bills net between the same two people.
    expect(pairs.firstWhere((p) => p.$1 == b).$2, BigInt.from(6000));
  });

  test('a one-member group has nothing to work out', () {
    final g = group(people: {a: person('Ana', user: 'me')});
    expect(sharedStanding(g, a).kind, StandingKind.square);
    expect(pairsWithMe(g, a), isEmpty);
    expect(peopleTotals(g, a), isEmpty);
    expect(sharedBillRows(g, a), isEmpty);
    expect(sharedPaymentRows(g, a, today), isEmpty);
  });
}

SharedSource sourceFor(
  List<SharedGroup> groups, {
  List<SharedJson> drafts = const [],
  List<SharedJson> intents = const [],
}) => SharedSource(
  today: today,
  groups: groups,
  loaded: true,
  connected: true,
  online: true,
  complete: true,
  hidden: false,
  amount: (v) => '$v',
  writer: const DemoSharedWriter(),
  profileName: 'Ana',
  actor: 'me',
  drafts: drafts,
  intents: intents,
);

void taskTests() {
  test('groups sort by what needs the user, then archived and left', () {
    SharedGroup named(
      String id,
      String name, {
      bool archived = false,
      bool active = true,
      SharedJson settlements = const {},
    }) => SharedGroup({
      'id': id,
      'name': name,
      'complete': true,
      'archived': archived,
      'people': {
        a: person('Ana', user: 'me', active: active),
        b: person('Ben', user: 'ben'),
      },
      'bills': <String, dynamic>{},
      'settlements': settlements,
      'activity': const [],
    });
    final rows = sharedGroupRows(
      sourceFor([
        named('1', 'Zebra'),
        named('2', 'Old', archived: true),
        named('3', 'Left', active: false),
        named('4', 'Apple'),
        named(
          '5',
          'Waiting',
          settlements: {'p': payment(b, a, '1', 'pending')},
        ),
      ]),
    );
    expect(rows.map((r) => r.group.name).toList().sublist(0, 3), [
      'Waiting',
      'Apple',
      'Zebra',
    ]);
    expect(rows.last.current, isFalse);
    expect(rows.first.toConfirm, 1);
  });

  test('tasks are split by tab, and a group’s drafts stay with it', () {
    final g = group();
    final tasks = sharedTasks(
      sourceFor(
        [g],
        drafts: [
          {
            'id': 'd1',
            'group_id': 'g',
            'payload': '{"op":"bill","fields":{"name":"Groceries"},"title":"Add shared expense"}',
          },
          {
            'id': 'd2',
            'group_id': 'g',
            'payload': '{"op":"report","fields":{"recipient":"$b"}}',
          },
          {
            'id': 'd3',
            'group_id': 'gone',
            'payload': '{"op":"bill","fields":{}}',
          },
        ],
        intents: [
          {
            'id': 'i1',
            'group_id': 'g',
            'state': 'review',
            'reason': 'Group changed; refresh and review',
            'payload': '{"op":"bill","values":{"name":"Rent"}}',
          },
          {
            'id': 'i2',
            'group_id': 'g',
            'state': 'pending',
            'payload': '{"op":"report","values":{"recipient":"$b"}}',
          },
          {
            'id': 'i3',
            'group_id': 'g',
            'state': 'reconciled',
            'payload': '{"op":"bill","values":{"name":"Done"}}',
          },
        ],
      ),
      g,
      scope: SharedTaskScope.bills,
    );
    expect(tasks.map((t) => t.title), [
      'Rent',
      'Groceries',
      'Untitled shared expense',
    ]);
    expect(
      tasks.first.detail,
      'The group changed while you were working. Check it and try again.',
    );
    expect(tasks.last.detail, 'Draft · its group isn’t here yet');
    final payments = sharedTasks(
      sourceFor(
        [g],
        drafts: [
          {
            'id': 'd2',
            'group_id': 'g',
            'payload': '{"op":"report","fields":{"recipient":"$b"}}',
          },
        ],
      ),
      g,
      scope: SharedTaskScope.payments,
    );
    expect(payments.single.title, 'Payment to Ben');
  });
}

void wordTests() {
  test('drafts get real titles', () {
    final g = group(
      bills: {
        'x': bill([
          revision('r', 'Dinner', '2026-10-10', '100', {a: '100'}, {a: '100'}),
        ]),
      },
    );
    expect(
      draftTitle({
        'op': 'bill',
        'fields': {'name': ' Rent '},
      }, g),
      'Rent',
    );
    expect(draftTitle({'op': 'bill'}, g), 'Untitled shared expense');
    expect(
      draftTitle({'op': 'bill', 'source': 'x', 'refund': true}, g),
      'Refund on Dinner',
    );
    expect(
      draftTitle({'op': 'bill', 'source': 'gone', 'refund': true}, null),
      'Refund on a bill',
    );
    expect(
      draftTitle({'op': 'bill', 'source': 'x'}, g),
      'Correction to Dinner',
    );
    expect(draftTitle({'op': 'report'}, g), 'Payment between members');
  });

  test('saved work reads plainly', () {
    expect(intentState({'state': 'pending'}), 'Waiting to sync');
    expect(
      intentTitle({
        'op': 'create',
        'values': {'name': 'Trip'},
      }, null),
      'New group: Trip',
    );
    expect(intentTitle({'op': 'something'}, null), 'A group change');
  });

  test('server reasons change on screen, and unknown ones don’t leak', () {
    expect(
      sharedReason('Refund precedes bill'),
      'A refund can’t be dated before its bill.',
    );
    expect(sharedReason('Internal thing happened'), sharedReasonFallback);
    expect(sharedReason(null), sharedReasonFallback);
    // Our own rules are already plain.
    expect(
      sharedReason('This needs a connection. Connect, then try again.'),
      'This needs a connection. Connect, then try again.',
    );
  });

  test('typed amounts are exact, and never guessed', () {
    expect(typedAmount('12.50'), BigInt.from(1250));
    expect(typedAmount(''), isNull);
    expect(typedAmount('12.'), isNull);
    expect(typedOrZero(''), BigInt.zero);
    expect(typedOrZero('0.01'), BigInt.one);
  });
}

void demoTests() {
  test('the demo sample replays on week, month and year edges', () {
    for (final date in [
      '2026-01-01',
      '2026-01-31',
      '2026-02-28',
      '2028-02-29',
      '2026-03-01',
      '2026-03-31',
      '2026-06-30',
      '2026-10-31',
      '2026-11-01',
      '2026-12-28',
      '2026-12-31',
      '2027-01-03',
      '2027-01-04',
    ]) {
      final groups = demoSharedGroups(date);
      expect(groups.length, 5, reason: date);
      for (final g in groups.where((g) => g.complete)) {
        final total = g.positions().values.fold(BigInt.zero, (a, b) => a + b);
        expect(total, BigInt.zero, reason: '${g.name} on $date');
      }
      final home = groups.first;
      final me = home.participant(demoActor);
      final rows = sharedPaymentRows(home, me, date);
      expect(
        rows.where((p) => p.status == PaymentStatus.toConfirm).length,
        1,
        reason: date,
      );
      expect(
        rows.where((p) => p.status == PaymentStatus.waiting).length,
        greaterThan(0),
        reason: date,
      );
      expect(
        rows.firstWhere((p) => p.status == PaymentStatus.waiting).ahead,
        BigInt.zero,
        reason: 'Paying someone you owe: $date',
      );
    }
  });

  test('the sample covers what the screens have to show', () {
    final groups = demoSharedGroups(today);
    final home = groups.first, me = home.participant(demoActor);
    expect(home.people.values.any((p) => p['kind'] == 'manual'), isTrue);
    final rows = sharedBillRows(home, me);
    expect(rows.any((r) => r.corrected), isTrue);
    expect(rows.any((r) => r.refunds > 0), isTrue);
    expect(rows.any((r) => r.paidBy.contains(' and ')), isTrue);
    expect(
      {for (final p in sharedPaymentRows(home, me, today)) p.status},
      {...PaymentStatus.values},
    );
    expect(sharedStanding(groups[1], me).kind, StandingKind.youOwe);
    expect(groups[2].archived, isTrue);
    expect(sharedStanding(groups[2], me).kind, StandingKind.square);
    expect(groups[3].complete, isFalse);
    expect(groups[4].people.length, 1);
    expect(demoSharedGroups(today, empty: true), isEmpty);
  });

  test('the Overview’s row reads from the same payment', () {
    expect(
      demoToConfirmLine(today, (v) => '₱${phpDecimal(v)}'),
      'Tala logged ₱500.00 · Household',
    );
  });
}
