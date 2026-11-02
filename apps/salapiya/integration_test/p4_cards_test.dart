import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:salapiya/app.dart';
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_profiles.dart';
import 'package:salapiya/local/local_runtime.dart';

import 'package:salapiya/design_system/kit/kit.dart' show DateField;

import '../test/local_money_journey.dart';
import 'p1_local_money_test.dart' show NoNetworkProof;

Future<void> nativeEnter(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey('native-$key'));
  // Fields most people skip wait under More details.
  if (field.evaluate().isEmpty) {
    await localTap(tester, find.text('More details').last);
  }
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  final widget = tester.widget(field);
  if (widget is DateField) {
    widget.onChanged!(DateTime.parse(value));
    await tester.pumpAndSettle();
    return;
  }
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  await tester.runAsync(
    () async => tester
        .state<EditableTextState>(editable)
        .updateEditingValue(
          TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          ),
        ),
  );
  await localSettle(tester);
}

Future<void> nativeSave(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await localTap(tester, find.text('Review').last);
  await localWait(
    tester,
    () => find.text('Save reviewed values').evaluate().isNotEmpty,
  );
  await localAction(tester, 'Save reviewed values');
  await localWait(
    tester,
    () => find.text('Saved securely on this device.').evaluate().isNotEmpty,
  );
  await localAction(tester, 'Done');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('P4 cards through the normal offline production application', (
    tester,
  ) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/p4-cards-${newLocalId()}');
    final slot = 'salapiya.p4.cards.${newLocalId()}';
    final profiles = LocalProfiles(directory, OsProfileVault(slot: slot));
    final settings = GallerySettings();
    final runtime = LocalRuntime(profiles, settings);
    final previousNetwork = HttpOverrides.current, network = NoNetworkProof();
    HttpOverrides.global = network;
    var runtimeClosed = false;
    try {
      await tester.runAsync(runtime.reopen);
      await tester.pumpWidget(
        SalapiyaApp(
          production: true,
          settings: settings,
          localRuntime: runtime,
        ),
      );
      await localSettle(tester);
      await localTap(tester, find.byKey(const ValueKey('greeting-start')));
      await localAction(tester, 'Start on this device');
      await tester.enterText(find.byType(TextField), 'P4 synthetic owner');
      await localAction(tester, 'Create profile');
      await localWait(tester, () => runtime.session != null);
      await localTap(tester, find.byKey(const ValueKey('nav-money')));
      await localAction(tester, 'Add account');
      await localEnter(tester, 'name', 'P4 wallet');
      await localEnter(tester, 'amount', '5000.00');
      await localConfirm(tester);
      final c = runtime.session!.localFinance;
      final account = c.snapshot.accounts.single.id;
      await localAction(tester, 'Cards');
      await localTap(tester, find.byKey(const ValueKey('cards-add')).first);
      await localWait(
        tester,
        () => find.byKey(const ValueKey('native-submit')).evaluate().isNotEmpty,
      );
      await nativeEnter(tester, 'name', 'P4 card');
      await nativeEnter(tester, 'issuer', 'Synthetic issuer');
      await nativeEnter(tester, 'limit', '10000.00');
      await nativeSave(tester);
      final card = c.snapshot.current
          .singleWhere((r) => financeType(r) == 'creditCard')
          .actionId;
      await localAction(tester, 'Log expense');
      await localEnter(tester, 'name', 'Native card dinner');
      await localEnter(tester, 'amount', '1200.00');
      await localTap(tester, find.byKey(const ValueKey('select-funding')));
      await localTap(tester, find.text('Credit card').last);
      await localConfirm(tester);
      expect(c.snapshot.balance(account), BigInt.from(500000));
      expect(
        financeBalance(c.snapshot, 'card_liability', 'card', card),
        BigInt.from(-120000),
      );
      expect(c.recognizedSpending, BigInt.from(120000));
      await localAction(tester, 'Log a card payment');
      await localWait(
        tester,
        () => find.byKey(const ValueKey('native-submit')).evaluate().isNotEmpty,
      );
      await nativeEnter(tester, 'name', 'Native repayment');
      await nativeEnter(tester, 'amount', '1500.00');
      await localTap(tester, find.byKey(const ValueKey('native-select-card')));
      await localTap(tester, find.text('P4 card').last);
      await localTap(
        tester,
        find.byKey(const ValueKey('native-select-account')),
      );
      await localTap(tester, find.text('P4 wallet').last);
      await nativeSave(tester);
      expect(c.snapshot.balance(account), BigInt.from(350000));
      expect(
        financeBalance(c.snapshot, 'card_liability', 'card', card),
        BigInt.from(30000),
      );
      expect(c.recognizedSpending, BigInt.from(120000));
      expect(find.textContaining('Card credit ₱300.00'), findsOneWidget);
      Future<void> select(String key, String label) async {
        await localTap(tester, find.byKey(ValueKey('native-select-$key')));
        await localTap(tester, find.textContaining(label).last);
      }

      /// Fills a form opened by [open]. Card pages prefill what they can.
      Future<String> record(
        Future<void> Function() open,
        String name,
        Map<String, String> fields, {
        Map<String, String> choices = const {},
        bool verified = false,
      }) async {
        await open();
        await localWait(
          tester,
          () =>
              find.byKey(const ValueKey('native-submit')).evaluate().isNotEmpty,
        );
        await nativeEnter(tester, 'name', name);
        for (final field in fields.entries) {
          await nativeEnter(tester, field.key, field.value);
        }
        for (final choice in choices.entries) {
          await select(choice.key, choice.value);
        }
        if (verified) {
          await select('verified', 'Yes');
        }
        await nativeSave(tester);
        return c.snapshot.current.singleWhere((r) => r.title == name).id;
      }

      Future<void> menu(String more, String item) async {
        await localTap(tester, find.byKey(ValueKey(more)));
        await localTap(tester, find.byKey(ValueKey(item)));
      }

      Future<void> back() async {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await localSettle(tester);
      }

      final today = civilToday();
      await localTap(tester, find.text('P4 card').first);
      final statement = await record(
        () => menu('card-more', 'card-add-statement'),
        'Native provider statement',
        {
          'start': today,
          'end': today,
          'issued': today,
          'due': '2026-11-20',
          'amount': '1200.00',
          'minimum': '100.00',
          'reference': 'Synthetic provider evidence',
        },
        verified: true,
      );
      expect(c.recognizedSpending, BigInt.from(120000));
      expect(
        statementRecordedBalance(c.snapshot, c.snapshot.revision(statement)),
        BigInt.from(-30000),
      );
      await localTap(tester, find.byKey(ValueKey('row-statement-$statement')));
      await record(
        () => menu('statement-more', 'statement-match-activity'),
        'Native confirmed membership',
        {},
        choices: {'activity': 'Native card dinner'},
        verified: true,
      );
      final allocation = await record(
        () => menu('statement-more', 'statement-match-payment'),
        'Native provider allocation',
        {'amount': '1200.00'},
        choices: {'payment': 'Native repayment'},
        verified: true,
      );
      await back();
      final plan = await record(
        () => menu('card-more', 'card-add-plan'),
        'Native provider plan',
        {
          'schedule': 'first,2026-11-20,400.00,100.00\nsecond,2026-12-20,400.00\nthird,2027-01-20,400.00',
          'principal': '1200.00',
          'interest': '0.00',
          'fee': '0.00',
          'reference': 'Synthetic provider evidence',
        },
        choices: {
          'splitMode': 'Different amounts',
          'purchase': 'Native card dinner',
        },
        verified: true,
      );
      await localTap(tester, find.text('Native provider plan').first);
      final application = await record(
        () => localTap(tester, find.byKey(const ValueKey('plan-match'))),
        'Native installment application',
        {'amount': '300.00'},
        choices: {'row': 'first', 'payment': 'Native provider allocation'},
        verified: true,
      );
      await back();
      await back();
      await menu('cards-menu', 'cards-history');
      await localAction(tester, 'Native installment application');
      await localAction(tester, 'Correct this record');
      await localWait(
        tester,
        () => find.byKey(const ValueKey('native-submit')).evaluate().isNotEmpty,
      );
      await nativeEnter(tester, 'amount', '200.00');
      await nativeEnter(
        tester,
        'reason',
        'Provider revised this explicit installment application',
      );
      await nativeSave(tester);
      await back();
      await back();
      final revisedApplication = c.snapshot.current.singleWhere(
        (r) => r.actionId == application,
      );
      expect(revisedApplication.number, 2);
      expect(revisedApplication.amount, BigInt.from(20000));
      expect(revisedApplication.postings, isEmpty);
      expect(c.snapshot.revision(plan).amount, BigInt.from(120000));
      expect(c.snapshot.revision(allocation).postings, isEmpty);
      expect(c.snapshot.balance(account), BigInt.from(350000));
      expect(c.recognizedSpending, BigInt.from(120000));
      await localTap(tester, find.text('P4 card').first);
      await record(
        () => menu('card-more', 'card-log-refund'),
        'Native actual card refund',
        {'amount': '100.00', 'reason': 'Actual provider credit'},
        choices: {'purchase': 'Native card dinner'},
      );
      await record(
        () => menu('card-more', 'card-log-fee'),
        'Native actual card fee',
        {'amount': '25.00'},
      );
      await record(
        () => menu('card-more', 'card-log-interest'),
        'Native actual card interest',
        {'amount': '15.00'},
      );
      await back();
      expect(c.snapshot.balance(account), BigInt.from(350000));
      expect(c.recognizedSpending, BigInt.from(114000));
      expect(
        financeBalance(c.snapshot, 'card_liability', 'card', card),
        BigInt.from(36000),
      );
      expect(find.textContaining('Card credit ₱360.00'), findsOneWidget);
      await tester.runAsync(c.store.integrity);
      expect(network.attempts, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(runtime.close);
      runtimeClosed = true;
      final reopened = await tester.runAsync(profiles.reopen);
      expect(
        financeBalance(
          await tester.runAsync(reopened!.snapshot) ?? c.snapshot,
          'card_liability',
          'card',
          card,
        ),
        BigInt.from(36000),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      if (!runtimeClosed) await tester.runAsync(runtime.close);
      await profiles.close();
      await OsProfileVault.storage.delete(key: slot);
      if (await directory.exists()) await directory.delete(recursive: true);
      settings.dispose();
      HttpOverrides.global = previousNetwork;
    }
  });
}
