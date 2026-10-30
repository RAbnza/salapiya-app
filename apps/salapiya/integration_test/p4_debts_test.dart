import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:salapiya/app.dart';
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_profiles.dart';
import 'package:salapiya/local/local_runtime.dart';

import '../test/local_money_journey.dart';
import 'p1_local_money_test.dart' show NoNetworkProof;
import 'p4_cards_test.dart' show nativeEnter, nativeSave;

Future<void> debtSelect(WidgetTester tester, String key, String choice) async {
  await localTap(tester, find.byKey(ValueKey('native-select-$key')));
  await localTap(tester, find.textContaining(choice).last);
}

/// A create action from the shell's New menu or + sheet.
Future<void> debtNew(WidgetTester tester, String label) async {
  await localTap(tester, find.byKey(const ValueKey('shell-new')));
  await localTap(tester, find.text(label).last);
}

/// One of a debt's actions, from the More menu on its page.
Future<void> debtMenu(WidgetTester tester, String debt, String key) async {
  await localTap(tester, find.byKey(const ValueKey('nav-debts')));
  await localTap(tester, find.text(debt).first);
  await localTap(tester, find.byKey(const ValueKey('debt-more')));
  await localTap(tester, find.byKey(ValueKey(key)));
}

Future<void> formReady(WidgetTester tester) => localWait(
  tester,
  () => find.byKey(const ValueKey('native-submit')).evaluate().isNotEmpty,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'P4 debt import, unknown actual payment, classification, schedule revision and reconciled payoff in production',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/p4-debts-${newLocalId()}');
      final slot = 'salapiya.p4.debts.${newLocalId()}';
      final profiles = LocalProfiles(directory, OsProfileVault(slot: slot));
      final settings = GallerySettings();
      final runtime = LocalRuntime(profiles, settings);
      final previousNetwork = HttpOverrides.current, network = NoNetworkProof();
      HttpOverrides.global = network;
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
        await localAction(tester, 'Create a local offline profile');
        await tester.enterText(find.byType(TextField), 'P4 debt owner');
        await localAction(tester, 'Create local profile');
        await localWait(tester, () => runtime.session != null);
        await localTap(tester, find.byKey(const ValueKey('nav-money')));
        await localAction(tester, 'Add account');
        await localEnter(tester, 'name', 'Debt wallet');
        await localEnter(tester, 'amount', '10000.00');
        await localConfirm(tester);
        final c = runtime.session!.localFinance,
            account = c.snapshot.accounts.single.id;
        await localTap(tester, find.byKey(const ValueKey('nav-debts')));
        await debtNew(tester, 'Add a debt');
        await formReady(tester);
        await nativeEnter(tester, 'name', 'Imported native debt');
        await nativeEnter(tester, 'lender', 'Synthetic provider');
        await nativeEnter(tester, 'amount', '6400.00');
        await nativeSave(tester);
        final debt = c.snapshot.current
            .singleWhere((r) => financeType(r) == 'debtImport')
            .actionId;
        expect(c.snapshot.balance(account), BigInt.from(1000000));
        await debtMenu(tester, 'Imported native debt', 'debt-edit-schedule');
        await localWait(
          tester,
          () => find
              .byKey(const ValueKey('native-select-frequency'))
              .evaluate()
              .isNotEmpty,
        );
        await debtSelect(tester, 'debt', 'Imported native debt');
        await debtSelect(tester, 'frequency', 'Monthly');
        await nativeEnter(tester, 'firstDue', '2026-11-20');
        await nativeEnter(tester, 'installmentCount', '2');
        await nativeSave(tester);
        await debtNew(tester, 'Log a debt payment');
        await formReady(tester);
        await debtSelect(tester, 'debt', 'Imported native debt');
        await debtSelect(tester, 'paymentRow', 'Installment 1');
        await nativeEnter(tester, 'amount', '1000.00');
        await debtSelect(tester, 'account', 'Debt wallet');
        await localTap(tester, find.byKey(const ValueKey('form-more-details')));
        await nativeEnter(tester, 'name', 'Unknown native payment');
        await nativeSave(tester);
        expect(c.snapshot.balance(account), BigInt.from(900000));
        expect(
          financeBalance(c.snapshot, 'debt_liability', 'debt', debt),
          BigInt.from(-640000),
        );
        expect(
          financeBalance(c.snapshot, 'debt_clearing', 'debt', debt),
          BigInt.from(100000),
        );
        await debtMenu(tester, 'Imported native debt', 'debt-break-down');
        await formReady(tester);
        await localTap(tester, find.byKey(const ValueKey('form-more-details')));
        await nativeEnter(tester, 'name', 'Known provider breakdown');
        await debtSelect(tester, 'debt', 'Imported native debt');
        await debtSelect(tester, 'payment', 'Unknown native payment ·');
        await nativeEnter(tester, 'reduction', '900.00');
        await nativeEnter(tester, 'interest', '100.00');
        await nativeEnter(tester, 'reason', 'Provider breakdown received');
        await nativeSave(tester);
        expect(c.snapshot.balance(account), BigInt.from(900000));
        expect(
          financeBalance(c.snapshot, 'debt_clearing', 'debt', debt),
          BigInt.zero,
        );
        await debtMenu(tester, 'Imported native debt', 'debt-edit-schedule');
        await formReady(tester);
        await nativeEnter(
          tester,
          'schedule',
          'Installment 1,2026-11-25,3200.00\nInstallment 2,2026-12-25,3200.00',
        );
        await nativeEnter(tester, 'firstDue', '2026-11-25');
        await nativeEnter(
          tester,
          'reason',
          'Provider revised due dates, preserve allocations',
        );
        await nativeSave(tester);
        await localTap(tester, find.byType(BackButton).first);
        await debtMenu(tester, 'Imported native debt', 'debt-early-payoff');
        await formReady(tester);
        await localTap(tester, find.byKey(const ValueKey('form-more-details')));
        await nativeEnter(tester, 'name', 'Reconciled native payoff');
        await debtSelect(tester, 'debt', 'Imported native debt');
        await debtSelect(tester, 'account', 'Debt wallet');
        await nativeEnter(tester, 'amount', '5500.00');
        await nativeEnter(tester, 'reduction', '5500.00');
        await nativeEnter(tester, 'reference', 'Provider closure');
        await nativeEnter(tester, 'reason', 'Exact provider payoff');
        await debtSelect(tester, 'verified', 'I confirmed this with my lender');
        await nativeSave(tester);
        expect(c.snapshot.balance(account), BigInt.from(350000));
        expect(
          financeBalance(c.snapshot, 'debt_liability', 'debt', debt),
          BigInt.zero,
        );
        expect(c.recognizedSpending, BigInt.from(10000));
        await debtNew(tester, 'Add a debt');
        await formReady(tester);
        await nativeEnter(tester, 'name', 'Native component loan');
        await nativeEnter(tester, 'lender', 'Provider');
        await nativeEnter(tester, 'amount', '1000.00');
        await nativeEnter(tester, 'principal', '2000.00');
        await nativeEnter(tester, 'outstandingPrincipal', '800.00');
        await nativeSave(tester);
        final componentDebt = c.snapshot.current
            .singleWhere((r) => r.title == 'Native component loan')
            .actionId;
        Future<String> adjustment(
          String name,
          String kind,
          String amount, {
          String? source,
        }) async {
          await debtMenu(tester, 'Native component loan', 'debt-lender-charge');
          await formReady(tester);
          await nativeEnter(tester, 'name', name);
          await debtSelect(tester, 'debt', 'Native component loan');
          await nativeEnter(tester, 'amount', amount);
          await debtSelect(
            tester,
            'adjustmentKind',
            {
              'recognized_charge': 'A charge from your lender',
              'recognized_waiver': 'A waiver from your lender',
              'rounding_charge': 'A small rounding charge',
              'rounding_waiver': 'A small rounding waiver',
              'avoided_future': 'A future charge you avoided',
            }[kind]!,
          );
          if (kind.endsWith('charge')) {
            await debtSelect(tester, 'category', 'Fees');
          }
          if (source != null) {
            await debtSelect(tester, 'waiverBasis', 'A charge you logged');
            await debtSelect(tester, 'chargeSource', '$source ·');
          }
          await nativeEnter(
            tester,
            'reason',
            'Exact synthetic provider evidence',
          );
          await nativeEnter(tester, 'reference', name);
          await debtSelect(
            tester,
            'verified',
            'I confirmed this with my lender',
          );
          await nativeSave(tester);
          return c.snapshot.current.singleWhere((r) => r.title == name).id;
        }

        final charge = await adjustment(
          'Native recognized interest',
          'recognized_charge',
          '100.00',
        );
        await debtNew(tester, 'Log a debt payment');
        await formReady(tester);
        await debtSelect(tester, 'debt', 'Native component loan');
        await debtSelect(tester, 'account', 'Debt wallet');
        await nativeEnter(tester, 'amount', '300.00');
        await localTap(tester, find.text('I have the exact breakdown'));
        await nativeEnter(tester, 'reduction', '250.00');
        await nativeEnter(tester, 'principalReduction', '200.00');
        await nativeEnter(tester, 'interest', '50.00');
        await localTap(tester, find.byKey(const ValueKey('form-more-details')));
        await nativeEnter(tester, 'name', 'Native known components');
        await nativeEnter(tester, 'reductionSources', '$charge,50.00');
        await nativeSave(tester);
        expect(
          debtPrincipalRange(
            c.snapshot,
            c.snapshot.revision(componentDebt),
            civilToday(),
          ),
          (BigInt.from(60000), BigInt.from(60000)),
        );
        await adjustment(
          'Native remaining interest waiver',
          'recognized_waiver',
          '50.00',
          source: 'Native recognized interest',
        );
        await adjustment(
          'Native avoided future interest',
          'avoided_future',
          '200.00',
        );
        await adjustment('Native residual charge', 'rounding_charge', '0.01');
        await adjustment(
          'Native residual waiver',
          'rounding_waiver',
          '0.01',
          source: 'Native residual charge',
        );
        await debtMenu(tester, 'Native component loan', 'debt-early-payoff');
        await formReady(tester);
        await localTap(tester, find.byKey(const ValueKey('form-more-details')));
        await nativeEnter(tester, 'name', 'Native component closure');
        await debtSelect(tester, 'debt', 'Native component loan');
        await debtSelect(tester, 'account', 'Debt wallet');
        await nativeEnter(tester, 'amount', '800.00');
        await nativeEnter(tester, 'reduction', '800.00');
        await nativeEnter(
          tester,
          'reason',
          'Reconciled after explicit source waiver and residual',
        );
        await nativeEnter(tester, 'reference', 'Component closure');
        await debtSelect(tester, 'verified', 'I confirmed this with my lender');
        await nativeSave(tester);
        expect(c.snapshot.balance(account), BigInt.from(240000));
        expect(
          financeBalance(c.snapshot, 'debt_liability', 'debt', componentDebt),
          BigInt.zero,
        );
        expect(c.recognizedSpending, BigInt.from(20000));
        await tester.runAsync(c.store.integrity);
        expect(network.attempts, 0);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(runtime.close);
        await profiles.close();
        await OsProfileVault.storage.delete(key: slot);
        if (await directory.exists()) await directory.delete(recursive: true);
        settings.dispose();
        HttpOverrides.global = previousNetwork;
      }
    },
  );
}
