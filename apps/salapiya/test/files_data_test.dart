import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_demo.dart';
import 'package:salapiya/connected/financial_contract.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/finance/files_data.dart';
import 'package:salapiya/finance/import_data.dart';
import 'package:salapiya/finance/money_data.dart';
import 'package:salapiya/finance/money_details.dart';
import 'package:salapiya/finance/record_facts.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_finance_controller.dart';

import 'local_money_journey.dart' show localSettle;
import 'local_test_support.dart';
import 'p1_widgets_test.dart' show closeWithWidgetClock;

class Book {
  Book() : s = demoOverviewSnapshot('2026-10-15', empty: true);
  LocalSnapshot s;
  int n = 0;
  String post(String kind, Map<String, String> values) {
    final id =
        '00000000-0000-4000-9000-${(++n).toRadixString(16).padLeft(12, '0')}';
    s = applyFinancialPlan(
      s,
      planLocal(
        s,
        LocalCommand(
          id: id,
          owner: s.owner,
          expectedVersion: s.version,
          kind: kind,
          values: {'acknowledge': 'false', ...values},
        ),
      ),
    );
    return id;
  }

  String account() => post('account', {
    'name': 'Bank',
    'kind': 'Bank',
    'amount': '1000.00',
    'cutoff': '2026-01-01',
  });

  String expense(String account) => post('expense', {
    'date': '2026-10-02',
    'name': 'Lunch',
    'account': account,
    'amount': '20.00',
    'category': 'category-food',
  });

  String file(String source, String name, {String date = '2026-10-03'}) =>
      post('financialFile', {
        'name': name,
        'date': date,
        'sourceRevision': source,
        'mime': name.endsWith('.png') ? 'image/png' : 'application/pdf',
        'size': '2048',
        'checksum': '0123456789abcdef' * 4,
      });
}

void main() {
  group('sizes and types', () {
    test('read for the eye', () {
      expect(fileSize(512), '512 bytes');
      expect(fileSize(2048), '2.0 KB');
      expect(fileSize(5 * 1024 * 1024), '5.0 MB');
      expect(fileType('application/pdf'), 'PDF');
      expect(fileType('image/jpeg'), 'JPEG');
    });
  });

  group('files', () {
    test('a row names its record, not an id', () {
      final b = Book();
      final expense = b.expense(b.account());
      final id = b.file(expense, 'a.pdf');
      final row = fileRows(b.s).single;
      expect(row.id, id);
      expect(row.attachedTo, 'Lunch');
      expect(row.attachedLabel, 'Expense');
      expect(row.type, 'PDF');
      expect(row.image, isFalse);
    });

    test('newest first', () {
      final b = Book();
      final expense = b.expense(b.account());
      b.file(expense, 'old.pdf', date: '2026-10-01');
      b.file(expense, 'new.pdf', date: '2026-10-09');
      expect(fileRows(b.s).map((r) => r.name), ['new.pdf', 'old.pdf']);
    });

    test('a file not looked for yet isn’t called missing', () {
      final b = Book();
      b.file(b.expense(b.account()), 'a.pdf');
      final row = fileRows(b.s).single;
      expect(row.state, FileState.unknown);
      expect(row.missing, isFalse);
    });

    test('on this device, missing and archived are told apart', () {
      final b = Book();
      final expense = b.expense(b.account());
      final here = b.file(expense, 'here.pdf');
      final gone = b.file(expense, 'gone.pdf');
      final old = b.file(expense, 'old.pdf');
      b.post('fileDetach', {
        'date': '2026-10-05',
        'name': 'Archived link',
        'file': old,
        'reason': 'Wrong record',
      });
      final rows = fileRows(b.s, present: {here: true, gone: false, old: true});
      FileState of(String id) => rows.firstWhere((r) => r.id == id).state;
      expect(of(here), FileState.here);
      expect(of(gone), FileState.missing);
      expect(of(old), FileState.archived);
    });

    test('tiles count linked files only', () {
      final b = Book();
      final expense = b.expense(b.account());
      final here = b.file(expense, 'here.pdf');
      final gone = b.file(expense, 'gone.pdf');
      final old = b.file(expense, 'old.pdf');
      b.post('fileDetach', {
        'date': '2026-10-05',
        'name': 'Archived link',
        'file': old,
        'reason': 'Wrong record',
      });
      final summary = FilesSummary(
        fileRows(
          b.s,
          present: {here: true, gone: false, old: false},
          checks: {here: null, gone: 'This file isn’t on this device.'},
        ),
      );
      expect(summary.linked.length, 2);
      expect(summary.onDevice, 1);
      expect(summary.missing, 1);
      expect(summary.verified, 1);
      expect(summary.totalSize, 4096);
      // Missing already says so; only a file that's here can fail a check.
      expect(summary.failed, isEmpty);
    });

    test('a file that fails its check is flagged', () {
      final b = Book();
      final id = b.file(b.expense(b.account()), 'a.pdf');
      final summary = FilesSummary(
        fileRows(b.s, present: {id: true}, checks: {id: 'Damaged'}),
      );
      expect(summary.failed.single.problem, 'Damaged');
      expect(summary.verified, 0);
    });
  });

  group('record labels', () {
    List<(String, String?)> facts(LocalSnapshot s, LocalRevision r) =>
        recordFacts(s, r, (v) => 'P$v', (id) => 'Food');

    test('names replace ids', () {
      final b = Book();
      final expense = b.expense(b.account());
      b.file(expense, 'a.pdf');
      final record = b.s.current.lastWhere(
        (r) => financeType(r) == 'financialFile',
      );
      final found = {for (final (k, v) in facts(b.s, record)) k: v};
      expect(found['Attached to'], 'Lunch');
      expect(found['File type'], 'PDF');
      expect(found['Size'], '2.0 KB');
    });

    test('a hidden amount stays hidden', () {
      final b = Book();
      b.post('creditCard', {
        'date': '2026-02-01',
        'name': 'Rewards',
        'issuer': 'Issuer',
        'amount': '0.00',
        'limit': '1000.00',
      });
      final card = b.s.current.lastWhere((r) => financeType(r) == 'creditCard');
      final found = recordFacts(b.s, card, (_) => 'Amount hidden', (_) => '');
      expect(found, contains(('Credit limit', 'Amount hidden')));
    });

    test('every demo record has a plain label and resolved facts', () {
      final s = demoSample('2026-10-15');
      for (final r in s.current) {
        expect(moneyLabel(r), isNot('Record'), reason: financeType(r));
        for (final (label, value) in facts(s, r)) {
          expect(
            value ?? '',
            isNot(matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}'))),
            reason: '$label on ${r.title}',
          );
        }
      }
    });

    test('money records keep their own lists', () {
      final b = Book();
      b.expense(b.account());
      final record = b.s.current.lastWhere((r) => r.kind == 'expense');
      expect(facts(b.s, record), isEmpty);
    });
  });

  group('the demo sample', () {
    test('has a finished import, one waiting, and its money nets to zero', () {
      final batches = importBatches(demoSample('2026-10-15'));
      expect(batches.length, 2);
      final done = batches.firstWhere((b) => !b.open);
      expect(done.status, ImportStatus.done);
      expect(done.importedCount, 3);
      expect(done.leftOut, 1);
      final waiting = batches.firstWhere((b) => b.open);
      expect(waiting.status, ImportStatus.ready);
      expect(waiting.stale, isFalse);
      expect(waiting.rows.where((r) => r.hasProblem), isNotEmpty);
      expect(waiting.rows.where((r) => r.hasWarning), isNotEmpty);
    });

    test('still ends on its balances, whatever the date', () {
      for (final today in const ['2026-03-01', '2026-10-31', '2027-01-01']) {
        final s = demoSample(today);
        expect(
          sumMinor(s.accounts.map((a) => s.balance(a.id, through: today))),
          BigInt.from(2930075),
          reason: today,
        );
      }
    });
  });

  group('Saved drafts', () {
    testWidgets('a file draft has a title, and opens Files', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late LocalFixture f;
      late LocalFinancialController c;
      await tester.runAsync(() async {
        f = await LocalFixture.open();
        await f.store.saveDraft('files:attach', newLocalId(), {
          'name': 'receipt.pdf',
        });
        c = LocalFinancialController(f.store, await f.store.snapshot());
        await c.reload();
      });
      var opened = 0;
      try {
        await tester.pumpWidget(
          MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: SalapiyaTheme.build(
              Brightness.light,
              platform: TargetPlatform.windows,
            ),
            home: SavedDraftsPage(controller: c, onFiles: () => opened++),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await localSettle(tester);
        expect(find.text('Attach a file'), findsOneWidget);
        expect(find.text('receipt.pdf'), findsOneWidget);
        await tester.tap(find.text('Attach a file'));
        await tester.pump();
        expect(opened, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
        await closeWithWidgetClock(tester, f.close);
      }
    });
  });
}
