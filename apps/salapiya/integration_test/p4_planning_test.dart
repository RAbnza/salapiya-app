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
import 'p4_debts_test.dart' show debtSelect;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'P4 real planning, actual links and reservation underfunding in the production application',
    (tester) async {
      final support = await getApplicationSupportDirectory(),
          slot = 'salapiya.p4.planning.${newLocalId()}';
      final directory = Directory(
        '${support.path}/p4-planning-${newLocalId()}',
      );
      final profiles = LocalProfiles(directory, OsProfileVault(slot: slot));
      final settings = GallerySettings();
      final runtime = LocalRuntime(profiles, settings);
      final previous = HttpOverrides.current, network = NoNetworkProof();
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
        await localTap(tester, find.byKey(const ValueKey('greeting-start')));
        await localAction(tester, 'Start on this device');
        await tester.enterText(find.byType(TextField), 'P4 planning owner');
        await localAction(tester, 'Create profile');
        await localWait(tester, () => runtime.session != null);
        await localTap(tester, find.byKey(const ValueKey('nav-money')));
        await localAction(tester, 'Add account');
        await localEnter(tester, 'name', 'Planning wallet');
        await localEnter(tester, 'amount', '1000.00');
        await localConfirm(tester);
        final c = runtime.session!.localFinance,
            account = c.snapshot.accounts.single.id;
        await localAction(tester, 'Planning');
        await localTap(tester, find.byKey(const ValueKey('goals-add')));
        await localWait(
          tester,
          () => find.byKey(const ValueKey('native-submit')).evaluate().isNotEmpty,
        );
        await nativeEnter(tester, 'name', 'Native buffer');
        await nativeEnter(tester, 'amount', '1000.00');
        await nativeSave(tester);
        final goal = c.snapshot.current
            .singleWhere((r) => financeType(r) == 'savingsGoal')
            .actionId;
        await localTap(tester, find.byKey(ValueKey('goal-aside-$goal')));
        await localWait(
          tester,
          () => find.byKey(const ValueKey('native-submit')).evaluate().isNotEmpty,
        );
        await nativeEnter(tester, 'name', 'Reserve actual cash');
        await debtSelect(tester, 'account', 'Planning wallet');
        await nativeEnter(tester, 'amount', '1000.00');
        await nativeSave(tester);
        expect(c.snapshot.balance(account), BigInt.from(100000));
        expect(savingsReserved(c.snapshot), BigInt.from(100000));
        await localTap(tester, find.byKey(const ValueKey('budgets-add')));
        await localWait(
          tester,
          () => find.byKey(const ValueKey('native-submit')).evaluate().isNotEmpty,
        );
        await nativeEnter(tester, 'name', 'Native zero budget');
        await debtSelect(tester, 'category', 'Food');
        await nativeEnter(tester, 'amount', '0.00');
        await nativeEnter(tester, 'start', '2026-10-01');
        await nativeEnter(tester, 'lastDay', '2026-10-31');
        await nativeSave(tester);
        await localTap(tester, find.byKey(const ValueKey('recurring-add')));
        await localWait(
          tester,
          () => find.byKey(const ValueKey('native-submit')).evaluate().isNotEmpty,
        );
        await nativeEnter(tester, 'name', 'Native recurring bill');
        await nativeEnter(tester, 'amount', '100.00');
        await debtSelect(tester, 'frequency', 'Every day');
        await nativeEnter(tester, 'count', '2');
        await debtSelect(tester, 'account', 'Planning wallet');
        await nativeSave(tester);
        final rule = c.snapshot.current
            .singleWhere((r) => financeType(r) == 'recurrence')
            .id;
        // Saving the item added its next 90 days.
        expect(
          c.snapshot.current.where(
            (r) => financeType(r) == 'recurrenceGenerate',
          ),
          hasLength(1),
        );
        expect(c.snapshot.balance(account), BigInt.from(100000));
        await localAction(tester, 'Log expense');
        await localEnter(tester, 'name', 'Actual native purchase');
        await localEnter(tester, 'amount', '500.00');
        await localConfirm(tester);
        expect(c.snapshot.balance(account), BigInt.from(50000));
        expect(supportedSavings(c.snapshot, goal, civilToday()), (
          BigInt.from(50000),
          BigInt.from(50000),
        ));
        await localTap(tester, find.text('Native recurring bill').first);
        await localTap(tester, find.byKey(const ValueKey('recurring-link')));
        await localWait(
          tester,
          () => find.byKey(const ValueKey('native-submit')).evaluate().isNotEmpty,
        );
        await nativeEnter(tester, 'name', 'Native partial actual link');
        await nativeEnter(tester, 'amount', '50.00');
        await debtSelect(tester, 'actual', 'Actual native purchase ·');
        await nativeSave(tester);
        expect(c.snapshot.balance(account), BigInt.from(50000));
        final occurrence = occurrenceIdentity(
          c.snapshot.revision(rule),
          civilToday(),
        );
        expect(
          sumMinor(
            effectiveRecurringLinks(
              c.snapshot,
              occurrence,
            ).map((r) => r.amount),
          ),
          BigInt.from(5000),
        );
        final link = c.snapshot.current.singleWhere(
          (r) => financeType(r) == 'recurrenceLink',
        );
        await localTap(tester, find.byTooltip('Actions for this date').first);
        await localTap(tester, find.byKey(ValueKey('date-unlink-${link.id}')));
        await localWait(
          tester,
          () => find.byKey(const ValueKey('native-submit')).evaluate().isNotEmpty,
        );
        await nativeEnter(tester, 'name', 'Native exact link reversal');
        await nativeEnter(
          tester,
          'reason',
          'Preserve actual money, remove mistaken link',
        );
        await nativeSave(tester);
        expect(effectiveRecurringLinks(c.snapshot, occurrence), isEmpty);
        expect(c.recognizedSpending, BigInt.from(50000));
        final tomorrow = DateTime.parse(civilToday())
            .add(const Duration(days: 1))
            .toIso8601String()
            .substring(0, 10);
        final forecast = financialForecast(
          c.snapshot,
          today: civilToday(),
          from: tomorrow,
          through: tomorrow,
        );
        expect(forecast.opening, BigInt.from(50000));
        expect(forecast.daily[tomorrow], BigInt.from(40000));
        await tester.runAsync(c.store.integrity);
        expect(network.attempts, 0);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(runtime.close);
        await profiles.close();
        await OsProfileVault.storage.delete(key: slot);
        if (await directory.exists()) await directory.delete(recursive: true);
        settings.dispose();
        HttpOverrides.global = previous;
      }
    },
  );
}
