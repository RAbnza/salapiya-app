import 'package:flutter/foundation.dart';
import 'package:salapiya/app/window_chrome.dart';
import 'package:salapiya/local/local_store.dart';
import 'package:salapiya/features/finance/presentation/financial_editor.dart';
import 'package:salapiya/features/finance/contracts/financial_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/features/finance/presentation/financial_widgets.dart';
import 'package:salapiya/finance/finance_screen.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_finance_controller.dart';

import 'local_test_support.dart';
import 'local_money_journey.dart';
import 'p1_widgets_test.dart' show closeWithWidgetClock;

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Geist',
    )..addFont(rootBundle.load('assets/fonts/geist/regular.ttf'))).load();
  });
  testWidgets(
    'native caption bridge follows resolved app theme without redundant calls',
    (tester) async {
      const channel = MethodChannel('dev.salapiya/window_chrome');
      final calls = <MethodCall>[];
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return true;
      });
      try {
        for (final brightness in [
          Brightness.light,
          Brightness.dark,
          Brightness.dark,
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: SalapiyaTheme.build(brightness),
              home: const WindowChrome(child: SizedBox.shrink()),
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(calls.length, 2);
        expect(calls[0].arguments, [false, 0xF3F4F6, 0x222126, 0xE3E4E9]);
        expect(calls[1].arguments, [true, 0x14151A, 0xF3F2F0, 0x3B3C41]);
      } finally {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
  testWidgets(
    'reviewed card fee saves once with no cash movement',
    polishFormJourney,
  );
  testWidgets(
    'lost save response checks the original durable command once',
    uncertainFormJourney,
  );
  testWidgets(
    'status semantics distinguish local save, acceptance, download and uncertainty',
    (tester) async {
      final semantics = tester.ensureSemantics();

      for (final brightness in Brightness.values) {
        for (final state in [
          'pending',
          'accepted',
          'reconciled',
          'review',
          'restored',
          null,
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: SalapiyaTheme.build(brightness),
              home: Scaffold(body: FormSyncStatus(state: state)),
            ),
          );
          expect(find.byType(FormStatus), findsOneWidget);
          final status = tester.widget<FormStatus>(find.byType(FormStatus));
          expect(
            status.tone,
            state == 'reconciled' ? NoticeTone.success : NoticeTone.warning,
          );
          expect(
            find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.liveRegion == true,
            ),
            findsWidgets,
          );
          expect(tester.takeException(), isNull);
        }
      }
      semantics.dispose();
    },
  );
}

Future<void> polishFormJourney(WidgetTester tester) async {
  final f = (await tester.runAsync(LocalFixture.open))!;
  LocalFinancialController? controller;
  try {
    late String wallet, card, id;
    await tester.runAsync(() async {
      wallet = await f.account('Polish cash', '500.00');
      card = await f.post('creditCard', {
        'name': 'Polish card',
        'issuer': 'Synthetic',
        'amount': '0.00',
        'limit': '10000.00',
      });
      id = newLocalId();
      await f.store.saveDraft('finance:cardFee:', id, {
        'name': 'Provider fee',
        'card': card,
        'amount': '25.00',
        'date': civilToday(),
        'postingDate': civilToday(),
        'category': 'category-food',
        'acknowledge': 'false',
      });
      controller = LocalFinancialController(f.store, await f.store.snapshot());
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: SalapiyaTheme.build(Brightness.light),
        home: FinancialEnvironment(
          production: true,
          child: NativeFinanceEditor(
            controller: controller!,
            operation: 'cardFee',
            title: 'Card fee',
          ),
        ),
      ),
    );
    await localSettle(tester);
    await localTap(tester, find.widgetWithText(FilledButton, 'Review'));
    expect(
      find.text('Card liability'),
      findsOneWidget,
      reason: tester
          .widgetList<FormStatus>(find.byType(FormStatus))
          .map((w) => w.message)
          .join(' / '),
    );
    expect(find.text('Increases by \u20b125.00'), findsNWidgets(2));
    expect(find.text('Cash movement'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    expect(find.textContaining('card liability: -25.00'), findsNothing);
    await localTap(tester, find.text('View financial evidence'));
    expect(find.textContaining('card liability: -25.00 PHP'), findsOneWidget);
    expect(find.text('Original command: $id'), findsOneWidget);
    await localTap(tester, find.text('View financial evidence'));
    await localTap(tester, find.text('Edit'));
    expect(find.byKey(const ValueKey('native-amount')), findsOneWidget);
    expect(controller!.snapshot.balance(wallet), BigInt.from(50000));
    await localTap(tester, find.widgetWithText(FilledButton, 'Review'));
    await localTap(tester, find.text('Save reviewed values'));
    expect(find.text('Card fee saved'), findsOneWidget);
    expect(controller!.snapshot.balance(wallet), BigInt.from(50000));
    expect(
      financeBalance(controller!.snapshot, 'card_liability', 'card', card),
      BigInt.from(-2500),
    );
    expect(controller!.snapshot.revisions.where((r) => r.id == id).length, 1);
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    controller?.dispose();
    await closeWithWidgetClock(tester, f.close);
  }
}

/// Inject a lost response and unavailable receipt read around a real SQLite save.
class LostResponseStore extends LocalStore {
  LostResponseStore(LocalStore source) : super(source.db, source.owner);
  bool lost = true;
  String? submitted;
  int submissions = 0;
  @override
  Future<String> commit(
    LocalCommand command, {
    bool interrupt = false,
    String? recordedAt,
    Future<void> Function()? afterRevision,
  }) async {
    submitted = command.id;
    submissions++;
    final result = await super.commit(
      command,
      interrupt: interrupt,
      recordedAt: recordedAt,
      afterRevision: afterRevision,
    );
    if (lost) throw StateError('Synthetic lost response');
    return result;
  }

  @override
  Future<bool> hasReceipt(String id) {
    if (lost) throw StateError('Synthetic unavailable receipt read');
    return super.hasReceipt(id);
  }
}

Future<void> uncertainFormJourney(WidgetTester tester) async {
  final f = (await tester.runAsync(LocalFixture.open))!;
  LocalFinancialController? controller;
  try {
    late String wallet;
    late LostResponseStore store;
    await tester.runAsync(() async {
      wallet = await f.account('Recovery wallet', '500.00');
      store = LostResponseStore(f.store);
      controller = LocalFinancialController(store, await f.store.snapshot());
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: SalapiyaTheme.build(Brightness.dark),
        home: FinancialEnvironment(
          production: true,
          child: FinancialEditor(
            controller: controller!,
            action: FinancialAction.expense,
            initial: {
              'name': 'Recovery fee',
              'amount': '25.00',
              'account': wallet,
              'date': civilToday(),
              'category': 'category-food',
            },
          ),
        ),
      ),
    );
    await localSettle(tester);
    await localTap(tester, find.byKey(const ValueKey('review-action')));
    await localTap(tester, find.byKey(const ValueKey('simulate-action')));
    expect(find.text('The result is uncertain'), findsOneWidget);
    expect(
      find.text('Nothing was applied. Your draft is ready to retry.'),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('simulate-action')), findsNothing);
    expect(store.submissions, 1);
    final original = store.submitted!;
    store.lost = false;
    await localTap(tester, find.text('Check original result'));
    await localWait(
      tester,
      () => find.text('Saved on this device').evaluate().isNotEmpty,
    );
    expect(controller!.snapshot.balance(wallet), BigInt.from(47500));
    expect(
      controller!.snapshot.revisions.where((r) => r.id == original).length,
      1,
    );
    expect(store.submissions, 1);
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    controller?.dispose();
    await closeWithWidgetClock(tester, f.close);
  }
}
