import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_demo.dart' show demoSample;
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/shared/shared_balances_tab.dart';
import 'package:salapiya/shared/shared_data.dart';
import 'package:salapiya/shared/shared_demo.dart';
import 'package:salapiya/shared/shared_domain.dart';
import 'package:salapiya/shared/shared_people_data.dart';
import 'package:salapiya/shared/shared_private_data.dart';

import 'shared_data_test.dart' show a, b, c, today, bill, revision, payment;
import 'shared_data_test.dart' as fixture show group;

final sample = fixture.group;

BigInt minor(int n) => BigInt.from(n);

void main() {
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
  final lunch = bill([
    revision(
      'r2',
      'Lunch',
      '2026-10-12',
      '20000',
      {b: '20000'},
      {a: '10000', b: '10000'},
    ),
  ], creator: b);

  group('between two people', () {
    test('empty data has nothing between them', () {
      final p = pairBreakdown(sample(), a, b, a, today)!;
      expect(p.rows, isEmpty);
      expect(p.net, BigInt.zero);
    });

    test('reciprocal bills net, and the running net ends on the rule', () {
      // §16: Ana is owed 100 on Dinner and owes 100 on Lunch.
      final g = sample(bills: {'x': dinner, 'y': lunch});
      final p = pairBreakdown(g, a, b, a, today)!;
      expect(p.rows.map((r) => r.title), ['Dinner', 'Lunch']);
      expect(p.rows.first.change, minor(-10000));
      expect(p.rows.last.change, minor(10000));
      expect(p.rows.last.net, BigInt.zero);
      expect(p.net, g.due(a, b));
      expect(p.bills, 2);
      expect(whoOwesRows(g, a).where((e) => e.sender == a), isEmpty);
    });

    test('rows run by date, with bills before payments on a day', () {
      final g = sample(
        bills: {'x': dinner},
        settlements: {
          'p1': payment(
            b,
            a,
            '4000',
            'confirmed',
            date: '2026-10-10',
            allocations: {
              'x': {'revision': 'r1', 'amount': '4000'},
            },
          ),
        },
      );
      final p = pairBreakdown(g, b, a, b, today)!;
      expect(p.rows.map((r) => r.kind), [
        PairRowKind.bill,
        PairRowKind.payment,
      ]);
      expect(p.rows.last.title, 'You paid Ana');
      expect(p.rows.last.net, minor(6000));
      expect(p.net, g.due(b, a));
    });

    test('a payment split across bills is one row', () {
      final g = sample(
        bills: {'x': dinner, 'z': dinner},
        settlements: {
          'p1': payment(
            b,
            a,
            '15000',
            'confirmed',
            allocations: {
              'x': {'revision': 'r1', 'amount': '10000'},
              'z': {'revision': 'r1', 'amount': '5000'},
            },
          ),
        },
      );
      final p = pairBreakdown(g, a, b, a, today)!;
      expect(p.payments, 1);
      expect(p.rows.last.change, minor(15000));
      expect(p.rows.last.net, minor(-5000));
    });

    test('paid ahead counts, on no bill', () {
      final g = sample(
        settlements: {
          'p1': payment(a, b, '2500', 'confirmed', advance: '2500'),
        },
      );
      final p = pairBreakdown(g, a, b, a, today)!;
      expect(p.rows.single.change, minor(-2500));
      expect(p.net, g.due(a, b));
    });

    test('refunds sit inside the bill they belong to', () {
      final refunded = bill(
        [
          revision(
            'r1',
            'Dinner',
            '2026-10-10',
            '30000',
            {a: '30000'},
            {a: '10000', b: '10000', c: '10000'},
          ),
        ],
        refunds: [
          {
            'id': 'f1',
            'date': '2026-10-11',
            'total': '3000',
            'received': {a: '3000'},
            'credits': {b: '3000'},
          },
        ],
      );
      final p = pairBreakdown(sample(bills: {'x': refunded}), b, a, b, today)!;
      expect(p.rows.single.change, minor(7000));
      expect(p.rows.single.detail, 'Refunded');
    });

    test('a corrected bill reads from its current version', () {
      final corrected = bill([
        revision(
          'r1',
          'Dinner',
          '2026-10-10',
          '30000',
          {a: '30000'},
          {a: '10000', b: '10000', c: '10000'},
        ),
        revision(
          'r2',
          'Dinner',
          '2026-10-09',
          '60000',
          {a: '60000'},
          {a: '20000', b: '20000', c: '20000'},
        ),
      ]);
      final p = pairBreakdown(sample(bills: {'x': corrected}), b, a, b, today)!;
      expect(p.rows.single.date, '2026-10-09');
      expect(p.rows.single.change, minor(20000));
      expect(p.rows.single.detail, 'Corrected');
    });

    test('waiting, disputed, cancelled and reversed move nothing', () {
      final g = sample(
        bills: {'x': dinner},
        settlements: {
          for (final (i, state) in const [
            'pending',
            'disputed',
            'cancelled',
            'reversed',
          ].indexed)
            'p$i': payment(
              b,
              a,
              '1000',
              state,
              allocations: {
                'x': {'revision': 'r1', 'amount': '1000'},
              },
            ),
        },
      );
      final p = pairBreakdown(g, b, a, b, today)!;
      expect(p.payments, 0);
      expect(p.notCounted.length, 4);
      expect(p.net, minor(10000));
      expect(p.projected, minor(9000));
    });

    test('a partial copy reads "Not available yet", not a figure', () {
      final g = sample(bills: {'x': dinner}, complete: false);
      expect(pairBreakdown(g, a, b, a, today), isNull);
      expect(personBreakdown(g, a), isNull);
      expect(whoOwesRows(g, a), isEmpty);
      expect(sharedSuggestions(g).$1, SuggestionState.unavailable);
    });
  });

  group('who owes whom', () {
    test('the user’s own pairs come first, largest first', () {
      final g = sample(
        bills: {
          'x': dinner,
          'y': bill([
            revision(
              'r3',
              'Rent',
              '2026-10-01',
              '90000',
              {c: '90000'},
              {b: '90000'},
            ),
          ], creator: c),
        },
      );
      final rows = whoOwesRows(g, a);
      expect(rows.first.recipient, a);
      expect(rows.last.sender, b);
      expect(rows.last.recipient, c);
    });

    test('what you owe and are owed add up to your position', () {
      final g = sample(bills: {'x': dinner, 'y': lunch});
      final totals = pairTotals(pairsWithMe(g, a));
      expect(totals.owed - totals.owe, g.positions()[a]);
      expect(totals.toPeople, 0);
      expect(totals.fromPeople, 1);
    });

    test('sources count each bill and payment once', () {
      final g = sample(
        bills: {'x': dinner, 'y': lunch},
        settlements: {
          'p1': payment(
            c,
            a,
            '3000',
            'confirmed',
            allocations: {
              'x': {'revision': 'r1', 'amount': '3000'},
            },
          ),
        },
      );
      final sources = pairSources(g);
      expect(sources[(a, b)], (2, 0));
      expect(sources[(a, c)], (1, 1));
      expect(sourceWords(1, 1), '1 bill · 1 payment');
    });
  });

  group('suggestions', () {
    test('a direct one is marked direct', () {
      final (state, rows) = sharedSuggestions(sample(bills: {'x': dinner}));
      expect(state, SuggestionState.ready);
      expect(rows.every((r) => r.direct), isTrue);
    });

    test('a redirected one isn’t, and positions are preserved', () {
      // B owes A, and C owes B. Matching sends C straight to A.
      final g = sample(
        bills: {
          'x': bill([
            revision(
              'r1',
              'One',
              '2026-10-01',
              '1000',
              {a: '1000'},
              {b: '1000'},
            ),
          ]),
          'y': bill([
            revision(
              'r2',
              'Two',
              '2026-10-02',
              '1000',
              {b: '1000'},
              {c: '1000'},
            ),
          ]),
        },
      );
      final (_, rows) = sharedSuggestions(g);
      expect(rows.single.sender, c);
      expect(rows.single.recipient, a);
      expect(rows.single.direct, isFalse);
      expect(rows.single.owed, BigInt.zero);
    });

    test('part direct is told apart from none of it', () {
      // C owes A 10 directly and 20 through B, so the suggestion is 30.
      final g = sample(
        bills: {
          'x': bill([
            revision(
              'r1',
              'One',
              '2026-10-01',
              '1000',
              {a: '1000'},
              {c: '1000'},
            ),
          ]),
          'y': bill([
            revision(
              'r2',
              'Two',
              '2026-10-02',
              '2000',
              {a: '2000'},
              {b: '2000'},
            ),
          ]),
          'z': bill([
            revision(
              'r3',
              'Three',
              '2026-10-03',
              '2000',
              {b: '2000'},
              {c: '2000'},
            ),
          ]),
        },
      );
      final (_, rows) = sharedSuggestions(g);
      final row = rows.single;
      expect(row.amount, minor(3000));
      expect(row.owed, minor(1000));
      expect(row.direct, isFalse);
      String words(BigInt v) => '₱${phpDecimal(v)}';
      expect(
        suggestionWords(row, g, c, words),
        startsWith('More than the ₱10.00 you owe Ana directly.'),
      );
    });

    test('a dispute pauses them, and all square has none', () {
      final g = sample(
        bills: {'x': dinner},
        settlements: {'p1': payment(b, a, '1000', 'disputed')},
      );
      expect(sharedSuggestions(g).$1, SuggestionState.paused);
      expect(sharedSuggestions(g).$2, isEmpty);
      expect(sharedSuggestions(sample()).$1, SuggestionState.none);
    });
  });

  test('what the balances count', () {
    final g = sample(
      bills: {'x': dinner},
      settlements: {
        'p1': payment(b, a, '1000', 'confirmed'),
        'p2': payment(c, a, '2000', 'pending'),
        'p3': payment(c, a, '3000', 'disputed'),
        'p4': payment(c, a, '4000', 'cancelled'),
      },
    );
    final n = balanceCounts(g);
    expect(n.bills, minor(30000));
    expect(n.billCount, 1);
    expect(n.confirmed, minor(1000));
    expect(n.waiting, minor(2000));
    expect(n.disputed, minor(3000));
    expect(n.waitingCount, 1);
  });

  group('a person', () {
    test('the breakdown adds up to the rules’ position', () {
      final g = sample(
        bills: {'x': dinner, 'y': lunch},
        settlements: {
          'p1': payment(
            c,
            a,
            '3000',
            'confirmed',
            allocations: {
              'x': {'revision': 'r1', 'amount': '3000'},
            },
          ),
          'p2': payment(b, c, '500', 'confirmed', advance: '500'),
          'p3': payment(c, a, '700', 'pending'),
        },
      );
      for (final p in [a, b, c]) {
        final n = personBreakdown(g, p)!;
        expect(n.paid - n.part + n.sent - n.received, g.positions()[p]);
        expect(n.position, g.positions()[p]);
      }
      expect(personBreakdown(g, c)!.waitingOut, minor(700));
      expect(personBreakdown(g, a)!.waitingIn, minor(700));
    });

    test('someone on no bill has an empty breakdown', () {
      final n = personBreakdown(sample(), a)!;
      expect(n.paid, BigInt.zero);
      expect(n.position, BigInt.zero);
    });

    test('their bills, refunds applied', () {
      final rows = personBills(sample(bills: {'x': dinner, 'y': lunch}), b);
      expect(rows.map((r) => r.name), ['Lunch', 'Dinner']);
      expect(rows.first.paid, minor(20000));
    });
  });

  group('members', () {
    final manual = {
      'name': 'Lola',
      'user': null,
      'kind': 'manual',
      'active': true,
      'intervals': const [],
    };
    final deleted = {
      'name': 'Deleted participant',
      'user': null,
      'kind': 'deleted',
      'active': false,
      'intervals': const [
        {'joined': '2026-01-01 04:00:00+00', 'role': 'member'},
        {
          'left': '2026-02-01 04:00:00+00',
          'reason': 'Provider identity deleted',
        },
      ],
    };
    final left = {
      'name': 'Marco',
      'user': 'marco',
      'kind': 'registered',
      'active': false,
      'intervals': const [
        {'joined': '2026-01-01 04:00:00+00', 'role': 'member'},
        {
          'left': '2026-03-01 04:00:00+00',
          'actor': 'marco',
          'reason': 'Moved out',
        },
      ],
    };
    final owner = {
      'name': 'Ana',
      'user': 'me',
      'kind': 'registered',
      'active': true,
      'intervals': const [
        {'joined': '2025-12-31 20:00:00+00', 'role': 'owner'},
      ],
    };
    final g = sample(people: {a: owner, b: manual, c: left, 'd': deleted});

    test('roles, status and dates on the Asia/Manila calendar', () {
      final rows = sharedMembers(g, a);
      expect(rows.map((m) => m.role), [
        MemberRole.owner,
        MemberRole.notRegistered,
        MemberRole.deleted,
        MemberRole.member,
      ]);
      // 20:00 UTC is the next morning in Manila.
      expect(rows.first.joined, '2026-01-01');
      expect(rows.first.active, isTrue);
      final marco = rows.firstWhere((m) => m.name == 'Marco');
      expect(marco.left, '2026-03-01');
    });

    test('a deleted account reads plainly; the stored name stays', () {
      expect(g.personName('d'), 'Deleted account');
      expect(g.people['d']['name'], 'Deleted participant');
      expect(g.personName('gone'), 'Earlier member');
    });

    test('history in plain words, newest first', () {
      expect(memberHistory(g, c).map((e) => e.title), ['Left', 'Joined']);
      expect(memberHistory(g, 'd').first.title, 'Account deleted');
      expect(memberHistory(g, 'd').first.reason, isNull);
      expect(memberHistory(g, a).single.title, 'Started the group');
      expect(memberHistory(g, b), isEmpty);
    });

    test('who can log for whom', () {
      expect(canLogFor(g, a, a), isTrue);
      expect(canLogFor(g, b, a), isTrue, reason: 'Not registered');
      expect(canLogFor(g, c, a), isFalse, reason: 'Registered, so their own');
      expect(canLogFor(g, a, null), isFalse);
      expect(canLogFor(g, a, c), isFalse, reason: 'Left');
    });

    test('a group of one has nothing between anyone', () {
      final one = sample(people: {a: owner});
      expect(whoOwesRows(one, a), isEmpty);
      expect(sharedSuggestions(one).$1, SuggestionState.none);
    });
  });

  group('my records', () {
    const groupId = 'g';
    LocalRevision record(
      String key,
      String mode, {
      String id = 'mine',
      String? revision,
      String? source,
      Map<String, String> values = const {},
      List<LocalPosting> postings = const [],
    }) => LocalRevision(
      id: id,
      actionId: id,
      kind: 'expense',
      change: 'create',
      date: '2026-10-10',
      title: 'Shared $mode · Group',
      amount: BigInt.zero,
      values: {
        'sharedGroup': groupId,
        'sharedKey': key,
        'sharedMode': mode,
        'sharedRevision': revision ?? 'r1',
        ...values,
      },
      postings: postings,
      number: 1,
      source: source,
    );
    final corrected = bill([
      revision(
        'r1',
        'Dinner',
        '2026-10-10',
        '30000',
        {a: '30000'},
        {a: '10000', b: '10000', c: '10000'},
      ),
      revision(
        'r2',
        'Dinner',
        '2026-10-10',
        '30000',
        {a: '30000'},
        {a: '10000', b: '10000', c: '10000'},
      ),
    ]);

    test('a bill the user isn’t on is never offered', () {
      final g = sample(
        bills: {
          'x': bill([
            revision(
              'r1',
              'Theirs',
              '2026-10-10',
              '10000',
              {b: '10000'},
              {b: '5000', c: '5000'},
            ),
          ], creator: b),
        },
      );
      expect(privateRows(g, a, const [], const [], today), isEmpty);
    });

    test('a bill reads not added, added, changed or kept', () {
      List<PrivateRow> rows(
        SharedGroup g,
        List<LocalRevision> current, [
        List<SharedJson> reviews = const [],
      ]) => privateRows(g, a, current, reviews, today);
      final plain = sample(bills: {'x': dinner});
      expect(rows(plain, const []).single.state, PrivateState.notAdded);
      expect(
        rows(plain, [record('x', 'bill')]).single.state,
        PrivateState.added,
      );
      final changed = sample(bills: {'x': corrected});
      expect(
        rows(changed, [record('x', 'bill')]).single.state,
        PrivateState.needsLook,
      );
      expect(
        rows(
          changed,
          [record('x', 'bill')],
          [
            {
              'group_id': groupId,
              'bill_id': 'x',
              'private_revision': 'mine',
              'source_stamp': sharedSourceStamp(object(changed.bills['x'])),
            },
          ],
        ).single.state,
        PrivateState.kept,
      );
    });

    test('a review from a backup doesn’t count', () {
      final g = sample(bills: {'x': corrected});
      final rows = privateRows(
        g,
        a,
        [record('x', 'bill')],
        [
          {
            'group_id': groupId,
            'bill_id': 'x',
            'private_revision': 'mine',
            'source_stamp': sharedSourceStamp(object(g.bills['x'])),
            'historicalOnly': true,
          },
        ],
        today,
      );
      expect(rows.single.state, PrivateState.needsLook);
    });

    test('a payment moves through added, to count, counted, taken out', () {
      SharedGroup with_(String state) => sample(
        settlements: {
          'p': {...payment(b, a, '1000', state), 'id': 'p'},
        },
      );
      PrivateState state(SharedGroup g, List<LocalRevision> current) =>
          privateRows(g, a, current, const [], today).single.state;
      final paid = record('p', 'payment', id: 'paid');
      final clear = record('p', 'clear', id: 'clear');
      final unclear = record('p', 'unclear', id: 'un', source: 'clear');
      expect(state(with_('pending'), const []), PrivateState.notAdded);
      expect(state(with_('pending'), [paid]), PrivateState.added);
      expect(state(with_('confirmed'), [paid]), PrivateState.toCount);
      expect(state(with_('confirmed'), [paid, clear]), PrivateState.counted);
      expect(state(with_('reversed'), [paid, clear]), PrivateState.toTakeOut);
      expect(
        state(with_('reversed'), [paid, clear, unclear]),
        PrivateState.takenOut,
      );
      expect(
        privateRows(with_('cancelled'), a, const [], const [], today),
        isEmpty,
      );
    });

    test('someone else’s payment isn’t listed', () {
      final g = sample(settlements: {'p': payment(b, c, '1000', 'confirmed')});
      expect(privateRows(g, a, const [], const [], today), isEmpty);
    });

    test('a group the user left lists only what’s linked', () {
      final g = sample(
        bills: {'x': dinner},
        people: {
          a: {
            'name': 'Ana',
            'user': 'me',
            'kind': 'registered',
            'active': false,
          },
          b: {
            'name': 'Ben',
            'user': 'ben',
            'kind': 'registered',
            'active': true,
          },
          c: {'name': 'Cy', 'user': 'cy', 'kind': 'registered', 'active': true},
        },
        complete: false,
      );
      expect(privateRows(g, a, const [], const [], today), isEmpty);
      expect(
        privateRows(g, a, [record('x', 'bill')], const [], today).length,
        1,
      );
    });

    test('a record whose source is gone stays listed', () {
      final rows = privateRows(
        sample(),
        a,
        [record('gone', 'bill')],
        const [],
        today,
      );
      expect(rows.single.gone, isTrue);
      expect(rows.single.state, PrivateState.needsLook);
      expect(rows.single.group, isNull);
    });

    test('what needs the user comes first', () {
      final g = sample(bills: {'x': dinner, 'y': corrected});
      final rows = privateRows(g, a, [record('y', 'bill')], const [], today);
      expect(rows.first.state, PrivateState.needsLook);
      expect(privateCounts(rows), (needs: 1, added: 1, notAdded: 1));
    });

    test('my records’ figure is a plain sum of this group’s', () {
      BigInt mine(String group) => myGroupBalance([
        record(
          'x',
          'bill',
          postings: [
            LocalPosting('shared_receivable', minor(600), today),
            LocalPosting('expense', minor(400), today),
            LocalPosting('cash', minor(-1000), today, account: 'cash'),
          ],
        ),
        record(
          'y',
          'bill',
          id: 'other',
          postings: [LocalPosting('shared_payable', minor(-250), today)],
        ),
      ], group);
      expect(mine(groupId), minor(350));
      expect(mine('another'), BigInt.zero);
    });

    test('stored titles read plainly, and others stay', () {
      expect(
        sharedRecordTitle('Shared clear · Household'),
        'Counted in group balance · Household',
      );
      expect(
        sharedRecordTitle('Shared unclear · Household'),
        'Taken out of group balance · Household',
      );
      expect(sharedRecordTitle('Dinner'), 'Dinner');
    });

    test('the sample shows every state the tab has to', () {
      const date = '2026-10-31';
      final s = demoSample(date);
      final g = demoSharedGroups(date).first;
      final mine = [
        for (final r in s.current)
          if (r.values.containsKey('sharedGroup')) r,
      ];
      final rows = privateRows(
        g,
        g.participant(demoActor),
        mine,
        const [],
        date,
      );
      final states = {for (final r in rows) r.state};
      expect(
        states,
        containsAll([
          PrivateState.notAdded,
          PrivateState.added,
          PrivateState.needsLook,
          PrivateState.toCount,
          PrivateState.counted,
        ]),
      );
      expect(myGroupBalance(mine, g.id), isNot(BigInt.zero));
      // Accounts still end on the demo's balances.
      expect(
        sumMinor(s.accounts.map((a) => s.balance(a.id, through: date))),
        BigInt.from(2930075),
      );
    });
  });

  group('the sample', () {
    for (final date in const [
      '2026-01-01',
      '2026-02-28',
      '2026-03-01',
      '2026-10-31',
      '2026-11-01',
      '2026-12-28',
      '2026-12-31',
      '2027-01-03',
    ]) {
      test('replays on $date, and every pair ends on the rule', () {
        final groups = demoSharedGroups(date);
        for (final g in groups.where((g) => g.complete)) {
          final me = g.participant(demoActor);
          final ids = g.people.keys.toList();
          for (final x in ids) {
            for (final y in ids.where((p) => p != x)) {
              final pair = pairBreakdown(g, x, y, me, date)!;
              expect(pair.net, g.due(x, y), reason: '${g.name}: $x $y');
              if (pair.rows.isNotEmpty) {
                expect(pair.rows.last.net, pair.net);
              }
            }
            final n = personBreakdown(g, x)!;
            expect(n.paid - n.part + n.sent - n.received, n.position);
          }
          final activity = [
            for (final e in g.data['activity'] as List) e['at'] as String,
          ];
          expect(activity, [...activity]..sort(), reason: g.name);
        }
      });
    }

    test('it has what Chat 11’s screens have to show', () {
      const date = '2026-10-31';
      final groups = demoSharedGroups(date);
      final home = groups.first, trip = groups[1];
      final me = home.participant(demoActor);
      expect(
        sharedMembers(home, me).any((m) => !m.active && m.left != null),
        isTrue,
      );
      expect(
        sharedMembers(trip, trip.participant(demoActor)).map((m) => m.role),
        contains(MemberRole.deleted),
      );
      expect(sharedSuggestions(home).$1, SuggestionState.paused);
      expect(sharedSuggestions(trip).$1, SuggestionState.ready);
      expect(trip.data['owner'], isNot(trip.participant(demoActor)));
      expect(
        memberHistory(groups[2], groups[2].participant(demoActor)!).first.title,
        'Became the owner',
      );
      // Rosa left with a balance: it isn't forgiven.
      final rosa = sharedMembers(home, me).firstWhere((m) => !m.active);
      expect(home.positions()[rosa.person], isNot(BigInt.zero));
      // Amounts are exact: nothing appears or goes missing.
      expect(sumMinor(home.positions().values), BigInt.zero);
    });
  });
}
