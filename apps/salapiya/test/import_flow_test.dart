import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/finance/import_data.dart';
import 'package:salapiya/finance/import_flow.dart';
import 'package:salapiya/finance/import_review.dart';
import 'package:salapiya/finance/money_details.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_finance_controller.dart';

import 'local_money_journey.dart' show localSettle, localTap, localWait;
import 'local_test_support.dart';
import 'p1_widgets_test.dart' show closeWithWidgetClock;

const header = 'date,kind,amount_minor,classification,description,reference';

List<int> csv(List<String> rows) => utf8.encode([header, ...rows].join('\n'));

String row(
  String date,
  String kind,
  int minor,
  String name, [
  String reference = '',
]) =>
    '$date,$kind,$minor,${kind == 'income' ? 'earned' : 'expense'},$name,$reference';

/// [count] small expenses with their own dates and references.
List<String> many(int count) => [
  for (var i = 0; i < count; i++)
    row(
      '2026-03-${(i % 28 + 1).toString().padLeft(2, '0')}',
      'expense',
      100,
      'Item $i',
      'R$i',
    ),
];

void main() {
  late LocalFixture f;
  late LocalFinancialController c;
  late String bank;

  Future<void> book() async {
    f = await LocalFixture.open();
    bank = await f.account('Bank', '5000.00', '2026-01-01');
    c = LocalFinancialController(f.store, await f.store.snapshot());
    await c.reload();
  }

  Future<ImportFlow> flowFor(
    List<String> rows, {
    String name = 'export.csv',
  }) async {
    final flow = ImportFlow(c, null);
    await flow.restore();
    flow.start(name, csv(rows));
    flow.draft['account'] = bank;
    await flow.persist();
    return flow;
  }

  ImportBatch only() => importBatches(c.snapshot).single;

  BigInt balance() => c.snapshot.balance(bank);

  group('a whole import', () {
    setUp(book);
    tearDown(() async {
      c.dispose();
      await f.close();
    });

    test(
      'rows go in only at the last step, and the draft goes with it',
      () async {
        final flow = await flowFor([
          row('2026-02-01', 'income', 100000, 'Pay', 'A1'),
          row('2026-02-02', 'expense', 25000, 'Lunch', 'A2'),
        ]);
        await flow.stage();
        expect(balance(), BigInt.from(500000));
        expect(only().status, ImportStatus.ready);
        await flow.confirm();
        expect(balance(), BigInt.from(500000));
        expect(only().status, ImportStatus.confirmed);
        await flow.importAll();
        expect(balance(), BigInt.from(575000));
        expect(only().status, ImportStatus.done);
        expect(only().importedCount, 2);
        expect(await f.store.draft(ImportFlow.operation), isNull);
        expect(flow.draft, isEmpty);
      },
    );

    test(
      'its commands hold what they always held, with the file’s name',
      () async {
        final flow = await flowFor([row('2026-02-01', 'income', 100, 'Pay')]);
        await flow.stage();
        final head = only().head;
        expect(head.title, 'export.csv');
        expect(
          head.values.keys,
          containsAll(['header', 'rowCount', 'checksum', 'assumptions']),
        );
        final assumptions = cashImportAssumptions(head);
        expect(assumptions['sourceFormat'], 'pmp-cash-activity');
        expect(assumptions['formatVersion'], 1);
        expect(assumptions['account'], bank);
        expect(assumptions['cutoffStrategy'], 'after_opening');
        expect((assumptions['mapping'] as Map).length, 6);
      },
    );

    test('groups of 50 go in one after another', () async {
      final flow = await flowFor(many(120));
      await flow.stage();
      await flow.confirm();
      await flow.importAll();
      expect(only().importedCount, 120);
      final groups = c.snapshot.current.where(
        (r) => financeType(r) == 'cashImportProcess',
      );
      expect(groups.length, 3);
      expect(
        [
          for (final g in groups)
            (jsonDecode(g.values['rowNumbers']!) as List).length,
        ],
        [50, 50, 20],
      );
    });

    test('rows left out stay out, and say so', () async {
      final flow = await flowFor([
        row('2026-02-01', 'income', 100, 'In'),
        row('2026-02-02', 'income', 200, 'Skip'),
      ]);
      await flow.stage();
      await flow.updateChoice(1, 'include', false);
      await flow.confirm();
      await flow.importAll();
      final b = only();
      expect(b.importedCount, 1);
      expect(b.leftOut, 1);
      expect(b.result(b.rows[1]), 'Left out');
      expect(b.status, ImportStatus.done);
    });

    test(
      'a lost response sends the same step again, and nothing twice',
      () async {
        final flow = await flowFor(many(60));
        await flow.stage();
        await flow.confirm();
        // The first group went through, and its answer never came back.
        flow.draft['process'] = newLocalId();
        flow.draft['processDate'] = civilToday();
        flow.draft['processRows'] = jsonEncode(
          nextCashImportRows(c.snapshot, flow.decision!),
        );
        await flow.persist();
        await submitCashImport(
          c,
          'cashImportProcess',
          {
            'name': 'Reviewed bounded cash-history import',
            'date': flow.draft['processDate']!,
            'decision': flow.decision!.id,
            'rowNumbers': flow.draft['processRows']!,
          },
          flow.draft['process']!,
          null,
        );
        final before = balance();
        expect(only().importedCount, 50);
        await flow.importAll();
        expect(only().importedCount, 60);
        expect(balance(), before - BigInt.from(1000));
      },
    );

    test('a retry with other details is refused', () async {
      final flow = await flowFor([row('2026-02-01', 'income', 100, 'Pay')]);
      await flow.stage();
      await expectLater(
        submitCashImport(
          c,
          'cashImport',
          {...flow.headValues(), 'rowCount': '9'},
          flow.draft['batch']!,
          null,
        ),
        throwsA(isA<LocalRuleException>()),
      );
    });

    test('Stop keeps what’s in and ends the rest for good', () async {
      final flow = await flowFor(many(60));
      await flow.stage();
      await flow.confirm();
      await flow.process();
      await flow.stopRemaining();
      final b = only();
      expect(b.status, ImportStatus.stopped);
      expect(b.importedCount, 50);
      expect(b.open, isFalse);
      expect(b.result(b.rows[59]), 'Stopped');
      expect(await f.store.draft(ImportFlow.operation), isNull);
    });

    test('Stop during a run ends after the group that’s going', () async {
      final flow = await flowFor(many(120));
      await flow.stage();
      await flow.confirm();
      var groups = 0;
      void watch() {
        if (flow.importedSoFar > groups) {
          groups = flow.importedSoFar;
          flow.stopping = true;
        }
      }

      flow.addListener(watch);
      await flow.importAll();
      flow.removeListener(watch);
      expect(only().status, ImportStatus.stopped);
      expect(only().importedCount, 50);
    });

    test('closing the page keeps the draft and its choices', () async {
      final flow = await flowFor([
        row('2026-02-01', 'income', 100, 'In'),
        row('2026-02-02', 'income', 200, 'Skip'),
      ]);
      await flow.stage();
      await flow.updateChoice(1, 'include', false);
      final back = ImportFlow(c, null);
      await back.restore();
      expect(back.draft['batch'], flow.draft['batch']);
      expect(back.choice(1)['include'], false);
    });

    test('an earlier import picks up with its own ids', () async {
      final flow = await flowFor(many(60));
      await flow.stage();
      await flow.confirm();
      await flow.process();
      final decision = flow.decision!.id;
      await f.store.discardDraft(ImportFlow.operation);
      final back = ImportFlow(c, null);
      await back.restore();
      expect(back.draft, isEmpty);
      await back.resume(only().head);
      expect(back.decision!.id, decision);
      await back.importAll();
      expect(only().importedCount, 60);
    });

    test(
      'an account that changed asks for the rows to be checked again',
      () async {
        final flow = await flowFor([row('2026-02-01', 'income', 100, 'In')]);
        await flow.stage();
        expect(only().stale, isFalse);
        await f.post('expense', {
          'name': 'Coffee',
          'account': bank,
          'amount': '10.00',
          'category': 'category-food',
        });
        await c.reload();
        expect(only().stale, isTrue);
        await expectLater(flow.confirm(), throwsA(isA<LocalRuleException>()));
        await flow.refresh();
        expect(only().stale, isFalse);
        await flow.confirm();
        await flow.importAll();
        expect(only().status, ImportStatus.done);
      },
    );

    test(
      'a row with a problem starts left out, and a duplicate needs a yes',
      () async {
        final flow = await flowFor([
          row('2025-12-01', 'expense', 100, 'Too early', 'D1'),
          row('2026-02-01', 'expense', 100, 'First', 'D2'),
          row('2026-02-02', 'expense', 100, 'Second', 'D2'),
        ]);
        await flow.stage();
        final rows = only().rows;
        expect(rows[0].hasProblem, isTrue);
        expect(flow.choice(0)['include'], false);
        expect(rows[2].hasWarning, isTrue);
        expect(flow.unconfirmed, [2]);
        await flow.updateChoice(2, 'acknowledgeDuplicates', true);
        expect(flow.unconfirmed, isEmpty);
      },
    );

    test('earlier history moves the start, with the rows, at once', () async {
      final flow = await flowFor([
        row('2025-11-01', 'income', 200000, 'Older pay'),
        row('2026-02-01', 'income', 100, 'Later'),
      ]);
      flow.draft['cutoffStrategy'] = 'rebase_history';
      flow.draft['earlierDate'] = '2025-10-01';
      flow.draft['earlierAmount'] = '3000.00';
      await flow.stage();
      expect(only().rebasePending, isTrue);
      await flow.confirm();
      await flow.importAll();
      expect(only().rebasePending, isFalse);
      expect(only().status, ImportStatus.done);
      expect(balance(), BigInt.from(500100));
    });
  });

  group('going below zero', () {
    setUp(book);
    tearDown(() async {
      c.dispose();
      await f.close();
    });

    test('consent shows only when it’s needed', () async {
      final fine = await flowFor([row('2026-02-01', 'expense', 100, 'Small')]);
      await fine.stage();
      expect(fine.needsConsent, isFalse);
    });

    test('with no consent the rule refuses, as the page warned', () async {
      final flow = await flowFor([
        row('2026-02-01', 'expense', 600000, 'Too much'),
      ]);
      await flow.stage();
      expect(flow.needsConsent, isTrue);
      await flow.confirm();
      await expectLater(flow.process(), throwsA(isA<LocalRuleException>()));
    });

    test('with consent it goes in', () async {
      final flow = await flowFor([
        row('2026-02-01', 'expense', 600000, 'Too much'),
      ]);
      await flow.stage();
      flow.draft['acknowledge'] = 'true';
      await flow.confirm();
      await flow.importAll();
      expect(balance(), BigInt.from(-100000));
    });

    test(
      'a group that dips counts, though the whole file ends above zero',
      () async {
        final expenses = [
          for (var i = 0; i < 50; i++)
            row(
              '2026-03-${(i % 28 + 1).toString().padLeft(2, '0')}',
              'expense',
              20000,
              'Big $i',
              'B$i',
            ),
        ];
        // Rows go in by file order, so this income arrives a group too late.
        final flow = await flowFor([
          ...expenses,
          row('2026-02-01', 'income', 5000000, 'Early pay', 'I1'),
        ]);
        await flow.stage();
        expect(flow.needsConsent, isTrue);
        await flow.confirm();
        await expectLater(flow.process(), throwsA(isA<LocalRuleException>()));
      },
    );
  });

  group('words', () {
    test('stored notes read plainly, and anything new passes through', () {
      expect(
        importRowNote('Matching reference'),
        'Same reference as another record',
      );
      expect(importRowNote('Something else'), 'Something else');
    });
  });

  group('the review page', () {
    Future<void> open(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(book);
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
      await closeWithWidgetClock(tester, f.close);
    }

    Future<void> show(
      WidgetTester tester,
      ImportFlow flow,
      TargetPlatform p,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: SalapiyaTheme.build(Brightness.light, platform: p),
          home: ImportReviewPage(
            flow: flow,
            source: (context) => localMoneySource(context, c, null),
          ),
        ),
      );
      await localSettle(tester);
    }

    for (final (platform, width) in const [
      (TargetPlatform.windows, 1200.0),
      (TargetPlatform.android, 360.0),
    ]) {
      testWidgets('the three steps, on $platform', (tester) async {
        await open(tester, width);
        try {
          late ImportFlow flow;
          await tester.runAsync(() async {
            flow = await flowFor([
              row('2026-02-01', 'income', 100000, 'Pay', 'A1'),
              row('2025-11-01', 'expense', 100, 'Too early', 'A2'),
            ]);
          });
          await show(tester, flow, platform);
          expect(find.textContaining('1. Match columns'), findsOneWidget);
          await localTap(
            tester,
            find.byKey(const ValueKey('import-check-rows')),
          );
          await localWait(
            tester,
            () => find
                .byKey(const ValueKey('import-confirm'))
                .evaluate()
                .isNotEmpty,
          );
          expect(tester.takeException(), isNull);
          expect(
            find.text('Dated on or before this account’s starting balance.'),
            findsOneWidget,
          );
          await localTap(tester, find.byKey(const ValueKey('import-confirm')));
          await localWait(
            tester,
            () => find
                .byKey(const ValueKey('import-run-all'))
                .evaluate()
                .isNotEmpty,
          );
          await localTap(tester, find.byKey(const ValueKey('import-run-all')));
          await localWait(
            tester,
            () => find
                .byKey(const ValueKey('import-finished'))
                .evaluate()
                .isNotEmpty,
          );
          expect(find.text('1 of 2 imported'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await close(tester);
        }
      });
    }

    testWidgets('a duplicate nobody confirmed stops Confirm, on its row', (
      tester,
    ) async {
      await open(tester, 1200);
      try {
        late ImportFlow flow;
        await tester.runAsync(() async {
          flow = await flowFor([
            row('2026-02-01', 'expense', 100, 'First', 'D1'),
            row('2026-02-02', 'expense', 100, 'Second', 'D1'),
          ]);
          await flow.stage();
        });
        await show(tester, flow, TargetPlatform.windows);
        expect(find.text('Same reference as another record'), findsOneWidget);
        await localTap(tester, find.byKey(const ValueKey('import-confirm')));
        await localSettle(tester);
        expect(
          find.text('Confirm this, or leave the row out.'),
          findsOneWidget,
        );
        expect(flow.decision, isNull);
      } finally {
        await close(tester);
      }
    });

    testWidgets('the below-zero consent shows only once it’s needed', (
      tester,
    ) async {
      await open(tester, 1200);
      try {
        late ImportFlow flow;
        await tester.runAsync(() async {
          flow = await flowFor([
            row('2026-02-01', 'expense', 600000, 'Too much'),
          ]);
          await flow.stage();
        });
        await show(tester, flow, TargetPlatform.windows);
        expect(find.byKey(const ValueKey('import-consent')), findsOneWidget);
        await localTap(tester, find.byKey(const ValueKey('import-confirm')));
        await localSettle(tester);
        expect(
          find.byKey(const ValueKey('import-consent-error')),
          findsOneWidget,
        );
        expect(flow.decision, isNull);
        await localTap(tester, find.byKey(const ValueKey('import-include-0')));
        await localSettle(tester);
        expect(find.byKey(const ValueKey('import-consent')), findsNothing);
      } finally {
        await close(tester);
      }
    });
  });
}
