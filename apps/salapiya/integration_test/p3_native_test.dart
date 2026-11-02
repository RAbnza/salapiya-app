import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:salapiya/connected/command_connector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:salapiya/app.dart';
import 'package:salapiya/gallery/settings.dart';
import 'package:salapiya/local/local_profiles.dart';
import 'package:salapiya/local/local_runtime.dart';
import 'package:salapiya/local/local_store.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/p0/auth_runtime.dart';
import 'package:salapiya/p0/google_auth_proof.dart';
import 'package:salapiya/shared/shared_domain.dart';
import 'package:salapiya/shared/shared_repository.dart';
import 'package:salapiya/p0/portable_recovery.dart';

import '../test/local_money_journey.dart';
import 'p2_native_test.dart' show PrivateDownload;

Future<void> p3Wait(
  WidgetTester tester,
  FutureOr<bool> Function() ready, {
  bool settle = true,
}) async {
  for (var i = 0; i < 400; i++) {
    if (await tester.runAsync(() async => await ready()) == true) {
      if (settle) await localSettle(tester);
      return;
    }
    await tester.pump(const Duration(milliseconds: 30));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
  }
  fail('P3 native operation did not complete.');
}

Future<void> p3Enter(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextField, label);
  await localWait(tester, () => field.evaluate().isNotEmpty);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  await tester.runAsync(() async {
    tester
        .state<EditableTextState>(editable)
        .updateEditingValue(
          TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          ),
        );
  });
  await localSettle(tester);
}

/// Types into a modal's field.
Future<void> p3EnterKey(WidgetTester tester, String key, String value) async {
  final field = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(EditableText),
  );
  await localWait(tester, () => field.evaluate().isNotEmpty);
  await tester.enterText(field, value);
  await localSettle(tester);
}

Future<void> p3Select(WidgetTester tester, String key, String label) async {
  final field = find.byKey(ValueKey('native-select-$key'));
  await p3Wait(tester, () => field.evaluate().isNotEmpty);
  await localTap(tester, field);
  await p3Choice(tester, label);
}

/// Use the real workspace tab after asynchronous CDC.
Future<void> p3TapSource(WidgetTester tester, String tab, String key) async {
  await localTap(tester, find.text(tab));
  final target = find.byKey(ValueKey(key));
  await p3Wait(tester, () => target.evaluate().isNotEmpty);
  await localTap(tester, target);
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

/// Opens a payment's page from the Payments tab: a table row on Windows, a
/// list row on a phone.
Future<void> p3OpenPayment(WidgetTester tester, String id) async {
  final row = find.byKey(ValueKey('row-$id'));
  final item = find.byKey(ValueKey('payment-$id'));
  await localWait(
    tester,
    () => row.evaluate().isNotEmpty || item.evaluate().isNotEmpty,
  );
  await localTap(tester, row.evaluate().isNotEmpty ? row : item);
}

/// A private action, from the More menu on a payment's page.
Future<void> p3PaymentMenu(WidgetTester tester, String key) async {
  await localTap(tester, find.byKey(const ValueKey('payment-menu')));
  await localTap(tester, find.byKey(ValueKey(key)));
}

Future<void> p3LeavePayment(WidgetTester tester) async {
  await Navigator.of(tester.element(find.byKey(const ValueKey('payment-menu'))))
      .maybePop();
  await localSettle(tester);
}

/// Review, then Save, then Done, on a Shared Expenses form.
Future<void> p3Submit(WidgetTester tester) async {
  final submit = find.byKey(const ValueKey('shared-submit'));
  await localTap(tester, submit);
  await localTap(tester, submit);
  await localTap(tester, find.byKey(const ValueKey('shared-done')));
}

Future<void> p3Choice(WidgetTester tester, String label) async {
  // Repeated isolated runs retain the user's/test profile history. Native
  // dropdowns lazily build long lists; scroll rather than resetting accounts.
  if (find.text(label).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(label),
      240,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 100,
    );
    await localSettle(tester);
  }
  await localTap(tester, find.text(label).last);
}

Future<void> p3Save(WidgetTester tester, {bool private = false}) async {
  if (private) {
    // One Review, then the page says it's saved. Done goes back.
    final submit = find.byKey(const ValueKey('private-submit'));
    await p3Wait(tester, () => submit.evaluate().isNotEmpty);
    await localTap(tester, submit);
    await p3Wait(
      tester,
      () => find.text('Save to my records').evaluate().isNotEmpty,
    );
    await localTap(tester, submit);
    final done = find.byKey(const ValueKey('private-done'));
    await p3Wait(tester, () => done.evaluate().isNotEmpty);
    await localTap(tester, done);
    return;
  }
  await localWait(tester, () => find.text('Review').evaluate().isNotEmpty);
  await localTap(tester, find.text('Review').last);
  await localWait(
    tester,
    () => find.text('Save reviewed values').evaluate().isNotEmpty,
  );
  await localTap(tester, find.text('Save reviewed values'));
  // Saving is asynchronous even when no progress spinner is shown. Wait for
  // the submitted form to close before reading its intent or opening a source.
  await p3Wait(
    tester,
    () =>
        find.text('Save reviewed values').evaluate().isEmpty &&
        find.text('Saving…').evaluate().isEmpty,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'P3 normal product UI, actual entitled CDC, exact bill, offline queue restart and private isolation',
    (tester) async {
      const configPath = String.fromEnvironment('P3_NATIVE_CONFIG_PATH');
      final support = await getApplicationSupportDirectory();
      final file = File(
        Platform.isWindows
            ? configPath
            : '${support.path}/p3-native-config.json',
      );
      final config = object(jsonDecode(await file.readAsString()));
      await file.delete();
      final role = config['role'] as String;
      final settings = GallerySettings();
      final profiles = LocalProfiles(
        Directory('${support.path}/p3-native-$role'),
        OsProfileVault(slot: 'salapiya.p3.native.$role'),
      );
      final runtime = LocalRuntime(profiles, settings);
      try {
        // Supabase restores persisted sessions asynchronously after initialize.
        // A fresh fixture scope avoids an old B session racing this A sign-in.
        final authScope = 'salapiya.p3.native.auth.$role.${newLocalId()}';
        final auth = await initializeProofAuth(
          config['url'] as String,
          config['publicKey'] as String,
          scope: authScope,
          detectSessionInUri: false,
        );
        await auth.client.auth.setSession(config['refreshToken'] as String);
        runtime.connected.flow = GoogleAuthProof(
          auth,
          authScope,
          const FlutterSecureStorage(),
        );
        await runtime.reopen();
        if (runtime.session == null) {
          final store = await profiles.retrieveConnected(
            config['profile'] as String,
            'P3 synthetic native',
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
        final store = runtime.session!.localFinance.store;
        var downloadAttempts = 0;
        await p3Wait(tester, () async {
          await store.reconcileSharedSnapshots();
          if (++downloadAttempts == 400) {
            debugPrint(
              'P3 download diagnostics: groups=${(await store.db.getAll("SELECT id FROM p3_group")).length}, resources=${(await store.db.getAll("SELECT id FROM p3_resource")).length}, connected=${store.db.currentStatus.connected}, error=${runtime.connected.error}',
            );
          }
          return (await store.db.getAll(
            'SELECT group_id FROM shared_snapshot_cache WHERE group_id=?',
            [config['nativeGroup']],
          )).isNotEmpty;
        });
        debugPrint('P3_NATIVE_STAGE: entitled shared download on $role.');
        if (const String.fromEnvironment('P3_NATIVE_STAGE') == 'verify') {
          final local = (await store.financialView()).$2;
          expect(local.version, config['expectedProfileVersion']);
          for (final row in config['expectedAccounts'] as List) {
            expect(
              local.balance(row['id'] as String).toString(),
              row['amount'],
            );
          }
          final group = SharedGroup(
            object(
              jsonDecode(
                (await store.db.get(
                      'SELECT document FROM shared_snapshot_cache WHERE group_id=?',
                      [config['nativeGroup']],
                    ))['document']
                    as String,
              ),
            ),
          );
          expect(group.version, config['expectedGroupVersion']);
          for (final p in object(config['expectedPositions']).entries) {
            expect(group.positions()[p.key].toString(), p.value);
          }
          expect(
            group.people.values
                .where((p) => p['user'] == auth.client.auth.currentUser!.id)
                .length,
            1,
          );
          return;
        }
        final baseline = (await store.db.get(
          'SELECT count(*) n FROM local_command',
        ))['n'];
        await localTap(tester, find.byKey(const ValueKey('nav-shared')));
        // Select this run's isolated active fixture rather than any old synthetic group.
        await p3OpenGroup(
          tester,
          config['nativeName'] as String? ?? 'P3 native shared group',
        );
        await localTap(tester, find.byKey(const ValueKey('People')));
        for (final name in ['Manual one windows', 'Manual two windows']) {
          final existing = SharedGroup(
            object(
              jsonDecode(
                (await store.db.get(
                      'SELECT document FROM shared_snapshot_cache WHERE group_id=?',
                      [config['nativeGroup']],
                    ))['document']
                    as String,
              ),
            ),
          );
          if (existing.people.values.any((p) => p['name'] == name)) continue;
          await localTap(tester, find.byKey(const ValueKey('people-add')));
          await p3EnterKey(tester, 'person-name', name);
          await localTap(tester, find.text('Add person').last);
          await localWait(tester, () => find.text(name).evaluate().isNotEmpty);
        }
        final raw = await store.db.get(
          'SELECT document FROM shared_snapshot_cache WHERE group_id=?',
          [config['nativeGroup']],
        );
        final group = SharedGroup(
          object(jsonDecode(raw['document'] as String)),
        );
        final title = 'Native PHP100 $role ${group.version}';
        await store.db.disconnect();
        await localAction(tester, 'Add shared expense');
        await localEnter(tester, 'name', title);
        await localEnter(tester, 'total', '100.00');
        await p3Submit(tester);
        await p3Wait(
          tester,
          () async => (await store.db.getAll(
            "SELECT id FROM shared_intent WHERE state='pending' AND queued=1",
          )).isNotEmpty,
        );
        expect(
          (await store.db.get('SELECT count(*) n FROM local_command'))['n'],
          baseline,
        );
        // Real loopback HTTP 503 failures exercise the production connector's
        // SDK transaction without shutting down either hosted provider. Then
        // discard a genuinely committed hosted response and reopen the queue.
        final archiveSecret = await PortableRecovery.newRecoverySecret();
        final oldArchive = await LocalBackup.seal(
          await LocalBackup.capture(store),
          archiveSecret,
        );
        final failureServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        var requests = 0, outage = true, responseLost = false;
        final serving = failureServer.listen((request) async {
          requests++;
          request.response.statusCode = 503;
          await request.response.close();
        });
        final http = HttpClient();
        final connector = FinancialConnector(
          store: store,
          actor: auth.client.auth.currentUser!.id,
          credentials: () async => null,
          submit: (id, envelope) async => object(
            await auth.client.rpc(
              'p2_submit_command',
              params: {'command_id': id, 'command_payload': envelope},
            ),
          ),
          submitShared: (id, envelope) async {
            if (outage) {
              final response = await (await http.getUrl(
                Uri.parse('http://127.0.0.1:${failureServer.port}/group'),
              )).close();
              await response.drain<void>();
              if (response.statusCode == 503) {
                throw const HttpException('Synthetic provider HTTP 503');
              }
            }
            final result = object(
              await auth.client.rpc(
                'p3_submit_command',
                params: {'command_id': id, 'command_payload': envelope},
              ),
            );
            expect(result['outcome'], 'accepted');
            responseLost = true;
            throw const HttpException('Synthetic lost committed response');
          },
        );
        await tester.runAsync(() async {
          for (var i = 0; i < 2; i++) {
            await expectLater(
              connector.uploadData(store.db),
              throwsA(isA<HttpException>()),
            );
          }
          outage = false;
          await expectLater(
            connector.uploadData(store.db),
            throwsA(isA<HttpException>()),
          );
        });
        expect(requests, 2);
        expect(responseLost, isTrue);
        debugPrint(
          'P3_NATIVE_STAGE: actual 503 and committed response loss on $role.',
        );
        http.close(force: true);
        await serving.cancel();
        await failureServer.close(force: true);
        // Same protected database/queue reopened by production profile manager.
        await tester.pumpWidget(const SizedBox.shrink());
        await profiles.close();
        final reopenedRuntime = runtime;
        await reopenedRuntime.reopen();
        await tester.pumpWidget(
          SalapiyaApp(
            production: true,
            settings: settings,
            localRuntime: reopenedRuntime,
          ),
        );
        await tester.runAsync(reopenedRuntime.connected.syncNow);
        final reopened = reopenedRuntime.session!.localFinance.store;
        await p3Wait(tester, () async {
          await reopened.reconcileShared();
          return (await reopened.db.getAll(
            "SELECT id FROM shared_intent WHERE state IN ('pending','accepted')",
          )).isEmpty;
        });
        debugPrint(
          'P3_NATIVE_STAGE: durable queue reopened and accepted once on $role.',
        );
        final accepted = SharedGroup(
          object(
            jsonDecode(
              (await reopened.db.get(
                    'SELECT document FROM shared_snapshot_cache WHERE group_id=?',
                    [config['nativeGroup']],
                  ))['document']
                  as String,
            ),
          ),
        );
        expect(
          accepted.bills.values
              .where((b) => (b['revisions'] as List).last['name'] == title)
              .length,
          1,
        );
        expect(
          accepted.positions().values.fold(BigInt.zero, (a, b) => a + b),
          BigInt.zero,
        );
        // Exercise private funding and recipient confirmation in the normal app
        // using a new isolated synthetic private account.
        await localTap(tester, find.byKey(const ValueKey('nav-money')));
        await localTap(tester, find.text('Add account'));
        final accountName = 'P3 cash $role ${newLocalId().substring(0, 8)}';
        await localEnter(tester, 'name', accountName);
        await localEnter(tester, 'amount', '2000.00');
        await localEnter(tester, 'cutoff', '2026-10-24');
        await localConfirm(tester);
        await p3Wait(
          tester,
          () async => (await reopened.db.getAll(
            "SELECT id FROM connected_intent WHERE state IN ('pending','accepted')",
          )).isEmpty,
        );
        await tester.runAsync(runtime.connected.syncNow);
        final account = (await reopened.snapshot()).accounts
            .firstWhere((a) => a.name == accountName)
            .id;
        final nativeBill = accepted.bills.entries
            .firstWhere(
              (b) => (b.value['revisions'] as List).last['name'] == title,
            )
            .key;
        await localTap(tester, find.byKey(const ValueKey('nav-shared')));
        await p3OpenGroup(
          tester,
          config['nativeName'] as String? ?? 'P3 native shared group',
        );
        await p3OpenBill(tester, title);
        await p3BillMenu(tester, 'private-bill-$nativeBill');
        await p3Select(tester, 'account', accountName);
        await p3Save(tester, private: true);
        await p3Wait(
          tester,
          () async => (await reopened.db.getAll(
            "SELECT id FROM connected_intent WHERE state IN ('pending','accepted')",
          )).isEmpty,
        );
        expect(
          (await reopened.snapshot()).balance(account),
          BigInt.from(190000),
        );
        await localAction(tester, 'Log a payment between members');
        await localTap(
          tester,
          find.byKey(const ValueKey('native-select-sender')),
        );
        await p3Choice(tester, 'Manual one windows');
        await localTap(
          tester,
          find.byKey(const ValueKey('native-select-recipient')),
        );
        await localTap(tester, find.textContaining('You').last);
        await localTap(tester, find.text('Choose bills'));
        await localEnter(tester, 'allocation:$nativeBill', '1.00');
        await p3Submit(tester);
        final reports = await reopened.db.getAll(
          "SELECT id,payload FROM shared_intent WHERE json_extract(payload,'\$.op')='report' AND group_id=?",
          [config['nativeGroup']],
        );
        final intent = reports.singleWhere((row) {
          final values = object(
            object(jsonDecode(row['payload'] as String))['values'],
          );
          final allocations = values['allocations'];
          return allocations is Map &&
              allocations[nativeBill] is Map &&
              object(allocations[nativeBill])['amount'] == '100';
        });
        final payment = intent['id'] as String;
        Future<SharedGroup> current() async => SharedGroup(
          object(
            jsonDecode(
              (await reopened.db.get(
                    'SELECT document FROM shared_snapshot_cache WHERE group_id=?',
                    [config['nativeGroup']],
                  ))['document']
                  as String,
            ),
          ),
        );
        await p3Wait(
          tester,
          () async => (await current()).settlements.containsKey(payment),
        );
        expect(
          (await current()).positions(),
          isNot((await current()).positions(projected: true)),
        );
        await localTap(tester, find.byKey(const ValueKey('Payments')));
        await p3OpenPayment(tester, payment);
        await p3PaymentMenu(tester, 'private-payment-$payment');
        await p3Select(tester, 'account', accountName);
        await p3Save(tester, private: true);
        await p3Wait(
          tester,
          () async => (await reopened.db.getAll(
            "SELECT id FROM connected_intent WHERE state IN ('pending','accepted')",
          )).isEmpty,
        );
        var cash = (await reopened.snapshot()).balance(account);
        expect(cash, BigInt.from(190100));
        await localTap(tester, find.byKey(const ValueKey('payment-confirm')));
        await localTap(tester, find.text('Confirm').last);
        await p3Wait(
          tester,
          () async =>
              (await current()).settlements[payment]['state'] == 'confirmed',
        );
        expect((await reopened.snapshot()).balance(account), cash);
        await p3PaymentMenu(tester, 'private-clear-$payment');
        await p3Save(tester, private: true);
        await p3Wait(
          tester,
          () async => (await reopened.db.getAll(
            "SELECT id FROM connected_intent WHERE state IN ('pending','accepted')",
          )).isEmpty,
        );
        await localTap(tester, find.byKey(const ValueKey('payment-undo')));
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('payment-reason')),
            matching: find.byType(TextField),
          ),
          'Synthetic recipient reversal',
        );
        await localTap(tester, find.text('Undo confirmation').last);
        await p3Wait(
          tester,
          () async =>
              (await current()).settlements[payment]['state'] == 'reversed',
        );
        await p3PaymentMenu(tester, 'private-unclear-$payment');
        await p3Save(tester, private: true);
        await p3Wait(
          tester,
          () async => (await reopened.db.getAll(
            "SELECT id FROM connected_intent WHERE state IN ('pending','accepted')",
          )).isEmpty,
        );
        expect((await reopened.snapshot()).balance(account), cash);
        expect(tester.takeException(), isNull);
        // Correct and refund the accepted group source through the real editor.
        // The private adoption is deliberately retained at its prior revision.
        await p3LeavePayment(tester);
        await p3OpenBill(tester, title);
        await localTap(
          tester,
          find.byKey(ValueKey('correct-bill-$nativeBill')),
        );
        await localEnter(tester, 'name', '$title corrected');
        await localEnter(
          tester,
          'reason',
          'Retain original immutable bill history',
        );
        await p3Submit(tester);
        await p3Wait(
          tester,
          () async =>
              ((await current()).bills[nativeBill]['revisions'] as List)
                  .length ==
              2,
        );
        expect((await reopened.snapshot()).balance(account), cash);
        final refundPeople = (await current()).people;
        String personNamed(String name) =>
            refundPeople.entries.firstWhere((p) => p.value['name'] == name).key;
        await localTap(tester, find.byKey(ValueKey('refund-bill-$nativeBill')));
        await localEnter(tester, 'total', '3.00');
        await localEnter(
          tester,
          'paid:${personNamed('Native fixture A')}',
          '3.00',
        );
        await localEnter(
          tester,
          'share:${personNamed('Manual one windows')}',
          '3.00',
        );
        await localEnter(
          tester,
          'reason',
          'Independent merchant money and consumption credit',
        );
        await p3Submit(tester);
        await p3Wait(
          tester,
          () async => ((await current()).bills[nativeBill]['refunds'] as List)
              .isNotEmpty,
        );
        expect((await reopened.snapshot()).balance(account), cash);
        final refundId =
            ((await current()).bills[nativeBill]['refunds'] as List)
                .single['id'];
        await p3BillMenu(tester, 'private-refund-$refundId');
        await p3Select(tester, 'account', accountName);
        await p3Save(tester, private: true);
        await p3Wait(
          tester,
          () async => (await reopened.db.getAll(
            "SELECT id FROM connected_intent WHERE state IN ('pending','accepted')",
          )).isEmpty,
        );
        cash += BigInt.from(300);
        expect((await reopened.snapshot()).balance(account), cash);
        // Continue a real Add Expense result into group sharing, then adopt its
        // original action. The group handoff cannot repeat the private cash.
        await localTap(tester, find.byKey(const ValueKey('nav-money')));
        await localAction(tester, 'Log expense');
        final integratedTitle = 'Integrated purchase $role ${accepted.version}';
        await localEnter(tester, 'name', integratedTitle);
        await localEnter(tester, 'amount', '3.00');
        await localTap(
          tester,
          find.byKey(const ValueKey('native-select-account')),
        );
        await p3Choice(tester, accountName);
        await localTap(tester, find.byKey(const ValueKey('native-submit')));
        await localTap(tester, find.byKey(const ValueKey('native-submit')));
        await localWait(
          tester,
          () => find.text('Share this purchase').evaluate().isNotEmpty,
        );
        await p3Wait(
          tester,
          () async => (await reopened.db.getAll(
            "SELECT id FROM connected_intent WHERE state IN ('pending','accepted')",
          )).isEmpty,
        );
        expect(
          (await reopened.snapshot()).balance(account),
          cash - BigInt.from(300),
        );
        cash -= BigInt.from(300);
        await localTap(tester, find.text('Share this purchase'));
        await localTap(tester, find.text(config['nativeName'] as String).last);
        await localWait(
          tester,
          () => find.text('Share your saved purchase').evaluate().isNotEmpty,
        );
        await p3Save(tester);
        // The approved sharing flow can return directly to the workspace or
        // retain the saved-purchase detail. Close that detail through Back.
        if (find.byKey(const ValueKey('nav-shared')).evaluate().isEmpty) {
          await localTap(tester, find.byType(BackButton).first);
        }
        await localTap(tester, find.byKey(const ValueKey('nav-shared')));
        await p3Wait(
          tester,
          () async => (await current()).bills.values.any(
            (b) => (b['revisions'] as List).last['name'] == integratedTitle,
          ),
        );
        final integratedBill = (await current()).bills.entries
            .firstWhere(
              (b) =>
                  (b.value['revisions'] as List).last['name'] ==
                  integratedTitle,
            )
            .key;
        await localTap(tester, find.text('Bills'));
        await p3TapSource(tester, 'Bills', 'private-bill-$integratedBill');
        // The saved purchase fills and locks its amount, date and account.
        await localEnter(tester, 'reason', 'Keep the original actual purchase');
        await p3Save(tester, private: true);
        await p3Wait(
          tester,
          () async => (await reopened.db.getAll(
            "SELECT id FROM connected_intent WHERE state IN ('pending','accepted')",
          )).isEmpty,
        );
        expect((await reopened.snapshot()).balance(account), cash);
        expect(tester.takeException(), isNull);
        // A genuinely older encrypted archive holds the original group command
        // before its server acceptance. A fresh independently keyed profile must
        // review its original receipt and download current authority/history.
        final restoredId = newLocalId();
        final recoveryProfiles = LocalProfiles(
          Directory('${support.path}/p3-recovery-$role-$restoredId'),
          OsProfileVault(slot: 'salapiya.p3.recovery.$role.$restoredId'),
        );
        final recovered = await recoveryProfiles.restore(
          await LocalBackup.unseal(oldArchive, archiveSecret),
        );
        expect(await recovered.db.getAll('SELECT id FROM p3_group'), isEmpty);
        expect((await recovered.connection())!['phase'], 'restored');
        final recoveryRuntime = LocalRuntime(
          recoveryProfiles,
          GallerySettings(),
        );
        recoveryRuntime.connected.flow = runtime.connected.flow;
        await recoveryRuntime.activate(recovered);
        await tester.pumpWidget(
          SalapiyaApp(
            production: true,
            settings: recoveryRuntime.settings,
            localRuntime: recoveryRuntime,
          ),
        );
        await tester.runAsync(recoveryRuntime.connected.syncNow);
        expect(recoveryRuntime.connected.error, isNull);
        final recoveryRepository = SharedRepository(recoveryRuntime, recovered);
        await recoveryRepository.open();
        for (final row in await recovered.db.getAll(
          "SELECT id FROM shared_intent WHERE state='restored'",
        )) {
          await recoveryRepository.retry(row['id'] as String);
        }
        await p3Wait(tester, () async {
          await recovered.reconcileShared();
          return (await recovered.db.getAll(
            "SELECT id FROM shared_intent WHERE state IN ('pending','accepted','restored')",
          )).isEmpty;
        });
        expect((await recovered.snapshot()).balance(account), cash);
        expect(
          (await recovered.financialView()).$2.version,
          (await reopened.financialView()).$2.version,
        );
        recoveryRepository.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        recoveryRuntime.connected.flow = null;
        await recoveryRuntime.close();
        // A separate live PowerSync connection uses the former member's signed JWT.
        final peerClient = SupabaseClient(
          config['url'] as String,
          config['publicKey'] as String,
        );
        final peerSession = (await peerClient.auth.setSession(
          config['otherRefreshToken'] as String,
        )).session!;
        final peerDb = openLocalDatabase(
          '${support.path}/p3-privacy-${newLocalId()}.sqlite',
          newLocalId(),
        );
        await peerDb.initialize();
        await peerDb.connect(
          connector: PrivateDownload(peerSession, config['endpoint'] as String),
        );
        await tester.runAsync(() => peerDb.waitForFirstSync());
        final records = await peerDb.getAll(
          'SELECT document FROM p3_group WHERE group_id=?',
          [config['group']],
        );
        expect(records, isNotEmpty);
        final former = SharedGroup(
          object(jsonDecode(records.single['document'] as String)),
        );
        expect(former.complete, isFalse);
        expect(
          await peerDb.getAll(
            "SELECT id FROM p3_resource WHERE group_id=? AND kind='bill' AND source_id=?",
            [config['group'], config['excludedBill']],
          ),
          isEmpty,
        );
        expect(
          await peerDb.getAll(
            "SELECT id FROM p3_resource WHERE group_id=? AND kind='bill'",
            [config['group']],
          ),
          isNotEmpty,
        );
        expect(
          await peerDb.getAll('SELECT id FROM p3_group WHERE group_id=?', [
            config['nativeGroup'],
          ]),
          isEmpty,
        );
        await peerDb.close();
        await peerClient.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await runtime.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
