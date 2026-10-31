import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:salapiya/app.dart';
import 'package:salapiya/design_system/kit/kit.dart' show OptionPicker;
import 'package:salapiya/finance/finance_screen.dart' show recordChoice;
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_profiles.dart';
import 'package:salapiya/local/local_runtime.dart';
import 'package:salapiya/p0/auth_runtime.dart';
import 'package:salapiya/p0/google_auth_proof.dart';
import 'package:salapiya/shared/shared_domain.dart';

import '../test/local_money_journey.dart';
import 'p3_native_test.dart'
    show p3Wait, p3Enter, p3Choice, p3Save, p3TapSource;
import 'p4_cards_test.dart' show nativeEnter;

Future<void> connectedFinanceSave(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await localTap(tester, find.text('Review').last);
  await localTap(tester, find.text('Save reviewed values'));
  await localWait(tester, () => find.text('Done').evaluate().isNotEmpty);
  await localTap(tester, find.text('Done'));
}

/// Opens a group: from the chooser, or from the switcher if one is open.
Future<void> p3OpenGroup(WidgetTester tester, String name) async {
  final switcher = find.byKey(const ValueKey('shared-switcher'));
  await localWait(
    tester,
    () =>
        switcher.evaluate().isNotEmpty || find.text(name).evaluate().isNotEmpty,
  );
  if (switcher.evaluate().isNotEmpty) await localTap(tester, switcher);
  await localTap(tester, find.text(name).last);
}

/// Opens a bill's page from the Bills tab.
Future<void> p3OpenBill(WidgetTester tester, String name) async {
  await localTap(tester, find.byKey(const ValueKey('Bills')));
  await localWait(tester, () => find.text(name).evaluate().isNotEmpty);
  await localTap(tester, find.text(name).first);
}

/// A private action, from the More menu on a bill's page.
Future<void> p3BillMenu(WidgetTester tester, String key) async {
  await localTap(tester, find.byKey(const ValueKey('bill-menu')));
  await localTap(tester, find.byKey(ValueKey(key)));
}

/// Review, then Save, then Done, on a Shared Expenses form.
Future<void> p3Submit(WidgetTester tester) async {
  final submit = find.byKey(const ValueKey('shared-submit'));
  await localTap(tester, submit);
  await localTap(tester, submit);
  await localTap(tester, find.byKey(const ValueKey('shared-done')));
}

/// Picks a saved record in a private form. Its label holds a date and a
/// formatted amount, so this goes by the record.
Future<void> p4Pick(WidgetTester tester, String key, String id) async {
  final field = find.byKey(ValueKey('native-select-$key'));
  await p3Wait(tester, () => field.evaluate().isNotEmpty);
  tester.widget<OptionPicker<String>>(field).onChanged!(id);
  await localSettle(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'P4 scenario 31 real native hosted card adoption, source revision and actual card refund',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final file = File(
        Platform.isWindows
            ? const String.fromEnvironment('P4_NATIVE_CONFIG_PATH')
            : '${support.path}/p4-native-config.json',
      );
      final config = object(jsonDecode(await file.readAsString()));
      await file.delete();
      final role = config['role'] as String, settings = GallerySettings();
      final profiles = LocalProfiles(
        Directory('${support.path}/p4-native-$role'),
        OsProfileVault(slot: 'salapiya.p4.native.$role'),
      );
      final runtime = LocalRuntime(profiles, settings),
          scope = 'salapiya.p4.native.auth.$role.${newLocalId()}';
      try {
        final auth = await initializeProofAuth(
          config['url'] as String,
          config['publicKey'] as String,
          scope: scope,
          detectSessionInUri: false,
        );
        await auth.client.auth.setSession(config['refreshToken'] as String);
        runtime.connected.flow = GoogleAuthProof(
          auth,
          scope,
          const FlutterSecureStorage(),
        );
        await runtime.reopen();
        if (runtime.connected.binding?['paused'] == 1) {
          await runtime.connected.pause(false);
        }
        if (runtime.session == null) {
          final store = await profiles.retrieveConnected(
            config['profile'] as String,
            'P4 synthetic native',
            auth.client.auth.currentUser!.id,
            auth.client.auth.currentUser!.email!,
          );
          await runtime.activate(store);
        }
        await tester.pumpWidget(
          SalapiyaApp(
            production: true,
            settings: settings,
            localRuntime: runtime,
          ),
        );
        await tester.runAsync(runtime.connected.syncNow);
        await localSettle(tester);
        final c = runtime.session!.localFinance, store = c.store;
        await p3Wait(tester, () async {
          await runtime.connected.refresh();
          return runtime.connected.complete &&
              (await store.db.getAll(
                'SELECT group_id FROM shared_snapshot_cache WHERE group_id=?',
                [config['group']],
              )).isNotEmpty;
        });
        Future<void> settled() async {
          await tester.runAsync(runtime.connected.syncNow);
          await p3Wait(tester, () async {
            await runtime.connected.refresh();
            return (await store.db.getAll(
              "SELECT id FROM connected_intent WHERE state IN ('pending','accepted')",
            )).isEmpty;
          });
          await tester.runAsync(c.reload);
        }

        Future<SharedGroup> group() async => SharedGroup(
          object(
            jsonDecode(
              (await store.db.get(
                    'SELECT document FROM shared_snapshot_cache WHERE group_id=?',
                    [config['group']],
                  ))['document']
                  as String,
            ),
          ),
        );
        if (const bool.fromEnvironment('P4_NATIVE_VERIFY_ONLY')) {
          await settled();
          final peer = role == 'windows' ? 'android' : 'windows';
          final peerCards = c.snapshot.current.where(
            (r) =>
                financeType(r) == 'creditCard' &&
                r.title.startsWith('P4 native $peer '),
          );
          final completed = peerCards.where((card) {
            final totals = <String, BigInt>{};
            for (final r in c.snapshot.current.where(
              (r) => r.values['card'] == card.actionId,
            )) {
              for (final p in r.postings) {
                totals[p.ledger] = (totals[p.ledger] ?? BigInt.zero) + p.amount;
              }
            }
            return totals['card_liability'] == BigInt.from(-111000) &&
                totals['expense'] == BigInt.from(37000) &&
                totals['shared_receivable'] == BigInt.from(74000);
          }).toList();
          expect(
            completed,
            isNotEmpty,
            reason: 'The other native device must first complete its hosted card journey.',
          );
          expect(runtime.connected.complete, isTrue);
          await tester.runAsync(store.integrity);
          debugPrint(
            'P4_NATIVE_PEER: $role received completed $peer card evidence through actual hosted CDC.',
          );
          return;
        }
        final suffix = newLocalId().substring(0, 8),
            cardName = 'P4 native $role $suffix',
            purchaseName = 'P4 card dinner $role $suffix';
        final cashBefore = c.liquid;
        await localTap(tester, find.byKey(const ValueKey('nav-money')));
        await localTap(tester, find.text('Cards').first);
        await localTap(tester, find.byKey(const ValueKey('cards-add')).first);
        await localWait(
          tester,
          () =>
              find.byKey(const ValueKey('native-submit')).evaluate().isNotEmpty,
        );
        await nativeEnter(tester, 'name', cardName);
        await nativeEnter(tester, 'issuer', 'Synthetic provider');
        await nativeEnter(tester, 'limit', '10000.00');
        await connectedFinanceSave(tester);
        await settled();
        final card = c.snapshot.current
            .singleWhere(
              (r) => financeType(r) == 'creditCard' && r.title == cardName,
            )
            .actionId;
        // Genuine SDK disconnect: the ordinary purchase remains durable locally
        // and becomes accepted only through the existing connector and CDC path.
        await tester.runAsync(() => runtime.connected.pause(true));
        await localAction(tester, 'Log expense');
        await localEnter(tester, 'name', purchaseName);
        await localEnter(tester, 'amount', '1200.00');
        await localTap(tester, find.byKey(const ValueKey('select-funding')));
        await localTap(tester, find.text('Credit card').last);
        await localTap(tester, find.byKey(const ValueKey('select-card')));
        await p3Choice(tester, cardName);
        await localConfirm(tester);
        expect(c.liquid, cashBefore);
        expect(
          financeBalance(c.snapshot, 'card_liability', 'card', card),
          BigInt.from(-120000),
        );
        expect(
          await tester.runAsync(
            () => store.db.getAll(
              "SELECT id FROM connected_intent WHERE state='pending'",
            ),
          ),
          isNotEmpty,
        );
        await tester.runAsync(() => runtime.connected.pause(false));
        await settled();
        final purchase = c.snapshot.current
            .singleWhere(
              (r) =>
                  r.title == purchaseName && financeType(r) == 'cardPurchase',
            )
            .id;
        expect(
          await tester.runAsync(
            () => store.db.getAll('SELECT id FROM p2_command WHERE id=?', [
              purchase,
            ]),
          ),
          hasLength(1),
        );
        await localTap(tester, find.byKey(const ValueKey('nav-shared')));
        await p3OpenGroup(tester, config['name'] as String);
        final people = (await group()).people;
        String personNamed(String name) =>
            people.entries.firstWhere((p) => p.value['name'] == name).key;
        await localAction(tester, 'Add shared expense');
        await localEnter(tester, 'name', purchaseName);
        await localEnter(tester, 'total', '1200.00');
        await localTap(tester, find.text('Exact amounts'));
        await localEnter(
          tester,
          'share:${personNamed('Native P4 owner')}',
          '400.00',
        );
        await localEnter(
          tester,
          'share:${personNamed('Native P4 consumer')}',
          '800.00',
        );
        await p3Submit(tester);
        await p3Wait(
          tester,
          () async => (await group()).bills.values.any(
            (b) => (b['revisions'] as List).last['name'] == purchaseName,
          ),
        );
        final bill = (await group()).bills.entries
            .singleWhere(
              (b) =>
                  (b.value['revisions'] as List).last['name'] == purchaseName,
            )
            .key;
        await p3OpenBill(tester, purchaseName);
        await p3BillMenu(tester, 'private-bill-$bill');
        await p4Pick(tester, 'existing', purchase);
        await localEnter(
          tester,
          'reason',
          'Adopt genuine native card purchase',
        );
        await p3Save(tester, private: true);
        await settled();
        var adopted = c.snapshot.current.singleWhere(
          (r) =>
              r.values['sharedKey'] == bill && r.values['sharedMode'] == 'bill',
        );
        expect(adopted.actionId, purchase);
        expect(c.liquid, cashBefore);
        await p3TapSource(tester, 'Bills', 'correct-bill-$bill');
        await p3Enter(tester, 'Description', '$purchaseName revised');
        await p3Enter(
          tester,
          'Reason',
          'Provider source description revised; funding unchanged',
        );
        await p3Save(tester);
        await p3Wait(
          tester,
          () async =>
              (await group()).revision(bill)['name'] == '$purchaseName revised',
        );
        await p3OpenBill(tester, purchaseName);
        await p3BillMenu(tester, 'private-bill-$bill');
        await localEnter(
          tester,
          'reason',
          'Review corrected source without replaying card funding',
        );
        await p3Save(tester, private: true);
        await settled();
        adopted = c.snapshot.current.singleWhere(
          (r) =>
              r.values['sharedKey'] == bill && r.values['sharedMode'] == 'bill',
        );
        expect(adopted.actionId, purchase);
        await localTap(tester, find.byKey(const ValueKey('nav-money')));
        await localTap(tester, find.text('Cards').first);
        await localTap(tester, find.text(cardName).first);
        await localTap(tester, find.byKey(const ValueKey('card-more')));
        await localTap(tester, find.byKey(const ValueKey('card-log-refund')));
        await localWait(
          tester,
          () =>
              find.byKey(const ValueKey('native-submit')).evaluate().isNotEmpty,
        );
        await nativeEnter(tester, 'name', 'Actual credit $suffix');
        await localTap(
          tester,
          find.byKey(const ValueKey('native-select-purchase')),
        );
        await p3Choice(tester, recordChoice(adopted));
        await nativeEnter(tester, 'amount', '90.00');
        await nativeEnter(tester, 'reason', 'Actual provider card credit');
        await connectedFinanceSave(tester);
        await settled();
        final credit = c.snapshot.current.singleWhere(
          (r) => r.title == 'Actual credit $suffix',
        );
        await localTap(tester, find.byKey(const ValueKey('nav-shared')));
        await localTap(
          tester,
          find.byWidgetPredicate(
            (w) =>
                w is DropdownButtonFormField<String> &&
                w.key.toString().contains('group-'),
          ),
        );
        await p3Choice(tester, config['name'] as String);
        await p3TapSource(tester, 'Bills', 'refund-bill-$bill');
        await p3Enter(tester, 'Refund total (PHP)', '90.00');
        await p3Enter(
          tester,
          'Native P4 owner · actual money received (PHP)',
          '90.00',
        );
        await p3Enter(
          tester,
          'Native P4 owner · consumed-share credit (PHP)',
          '30.00',
        );
        await p3Enter(
          tester,
          'Native P4 consumer · consumed-share credit (PHP)',
          '60.00',
        );
        await p3Enter(tester, 'Reason', 'Actual provider refund');
        await p3Save(tester);
        await p3Wait(
          tester,
          () async =>
              ((await group()).bills[bill]['refunds'] as List).isNotEmpty,
        );
        final refund =
            ((await group()).bills[bill]['refunds'] as List).last['id']
                as String;
        await p3TapSource(tester, 'Bills', 'private-refund-$refund');
        await p4Pick(tester, 'existingCardRefund', credit.id);
        await localEnter(
          tester,
          'reason',
          'Adopt actual card credit without another liability movement',
        );
        await p3Save(tester, private: true);
        await settled();
        final totals = <String, BigInt>{};
        for (final r in c.snapshot.current.where(
          (r) => r.values['card'] == card,
        )) {
          for (final p in r.postings) {
            totals[p.ledger] = (totals[p.ledger] ?? BigInt.zero) + p.amount;
          }
        }
        expect(totals, {
          'card_liability': BigInt.from(-111000),
          'expense': BigInt.from(37000),
          'shared_receivable': BigInt.from(74000),
        });
        expect(c.liquid, cashBefore);
        final raw =
            (await tester.runAsync(
                  () => store.db.get(
                    'SELECT document FROM shared_snapshot_cache WHERE group_id=?',
                    [config['group']],
                  ),
                ))!['document']
                as String;
        expect(raw, isNot(contains(card)));
        await tester.runAsync(store.integrity);
        expect(tester.takeException(), isNull);
        debugPrint(
          'P4_NATIVE_HOSTED: scenario 31 accepted and downloaded on $role; one liability and no cash replay.',
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(runtime.close);
        runtime.dispose();
        settings.dispose();
      }
    },
    skip: !const bool.fromEnvironment('P4_HOSTED_NATIVE'),
  );
}
