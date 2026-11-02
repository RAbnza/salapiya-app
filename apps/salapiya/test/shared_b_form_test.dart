import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/local/local_finance_controller.dart';
import 'package:salapiya/local/local_store.dart';
import 'package:salapiya/prototype/scenarios.dart';
import 'package:salapiya/shared/shared_data.dart';
import 'package:salapiya/shared/shared_domain.dart';
import 'package:salapiya/shared/shared_private_form.dart';

import 'local_money_journey.dart' show localSettle, localTap;
import 'local_test_support.dart';
import 'p1_widgets_test.dart' show closeWithWidgetClock;
import 'shared_form_test.dart' show FakeHub, FakeWriter, a, b, c;

const groupId = '20000000-0000-4000-8000-0000000000aa';
const dinner = '30000000-0000-4000-8000-0000000000b1';
const lunch = '30000000-0000-4000-8000-0000000000b2';
const refund = '30000000-0000-4000-8000-0000000000b3';
const paid = '40000000-0000-4000-8000-0000000000c1';
const date = '2026-10-10';

SharedGroup household() => SharedGroup({
  'id': groupId,
  'name': 'Household',
  'owner': a,
  'version': 3,
  'complete': true,
  'archived': false,
  'people': {
    a: {'name': 'Ana', 'user': 'me', 'kind': 'registered', 'active': true},
    b: {'name': 'Ben', 'user': 'ben', 'kind': 'registered', 'active': true},
    c: {'name': 'Cy', 'user': 'cy', 'kind': 'registered', 'active': true},
  },
  'bills': {
    dinner: {
      'creator': a,
      'revisions': [
        {
          'id': 'rev-dinner',
          'name': 'Dinner',
          'date': date,
          'total': '300000',
          'paid': {a: '300000'},
          'shares': {a: '100000', b: '100000', c: '100000'},
          'method': 'equal',
        },
      ],
      'refunds': [
        {
          'id': refund,
          'date': '2026-10-12',
          'total': '30000',
          'received': {a: '30000'},
          'credits': {a: '10000', b: '10000', c: '10000'},
          'reason': 'Returned a dish',
        },
      ],
    },
    lunch: {
      'creator': b,
      'revisions': [
        {
          'id': 'rev-lunch',
          'name': 'Lunch',
          'date': date,
          'total': '60000',
          'paid': {b: '60000'},
          'shares': {a: '30000', b: '30000'},
          'method': 'equal',
        },
      ],
      'refunds': const [],
    },
  },
  'settlements': {
    paid: {
      'id': paid,
      'sender': b,
      'recipient': a,
      'amount': '50000',
      'date': date,
      'state': 'confirmed',
      'allocations': const {},
      'advance': '50000',
      'manual': false,
      'events': const [],
    },
  },
  'activity': const [],
});

class HiddenHub extends FakeHub {
  HiddenHub(super.session, super.writer, super.groups);
  @override
  SharedSource source() {
    final s = super.source();
    return SharedSource(
      today: s.today,
      groups: s.groups,
      loaded: true,
      connected: true,
      online: true,
      complete: true,
      hidden: true,
      amount: (_) => 'Amount hidden',
      writer: s.writer,
      profileName: s.profileName,
      actor: s.actor,
    );
  }
}

void main() {
  late PrototypeSession session;
  setUp(() => session = PrototypeSession());
  tearDown(() => session.dispose());

  Future<(LocalFixture, LocalFinancialController, String)> open(
    WidgetTester tester, {
    String balance = '50000.00',
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final f = (await tester.runAsync(LocalFixture.open))!;
    late LocalFinancialController controller;
    late String wallet;
    await tester.runAsync(() async {
      wallet = await f.account('Wallet', balance, '2026-01-01');
      controller = LocalFinancialController(f.store, await f.store.snapshot());
      await controller.reload();
    });
    return (f, controller, wallet);
  }

  Future<void> close(
    WidgetTester tester,
    LocalFixture f,
    LocalFinancialController controller,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await closeWithWidgetClock(tester, f.close);
  }

  Future<FakeHub> form(
    WidgetTester tester,
    LocalFinancialController controller,
    String item,
    String mode, {
    FakeHub? using,
    TargetPlatform platform = TargetPlatform.windows,
  }) async {
    final hub = using ?? FakeHub(session, FakeWriter(), [household()]);
    addTearDown(hub.dispose);
    // Each form opens as a new page, so it never keeps the last one's state.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        themeAnimationDuration: Duration.zero,
        theme: SalapiyaTheme.build(Brightness.light, platform: platform),
        home: SharedPrivateForm(
          hub: hub,
          controller: controller,
          group: household(),
          item: item,
          mode: mode,
        ),
      ),
    );
    // It reads the store on real time before it shows anything.
    for (var i = 0; i < 300; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.byType(LoadingSkeleton).evaluate().isEmpty) break;
    }
    await localSettle(tester);
    return hub;
  }

  Finder submit() => find.byKey(const ValueKey('private-submit'));

  Future<void> enter(WidgetTester tester, String key, String value) async {
    final editable = find.descendant(
      of: find.byKey(ValueKey('native-$key')),
      matching: find.byType(EditableText),
    );
    tester
        .state<EditableTextState>(editable)
        .updateEditingValue(
          TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          ),
        );
    await tester.pump();
  }

  Future<void> pick(WidgetTester tester, String key, String value) async {
    tester
        .widget<OptionPicker<String>>(
          find.byKey(ValueKey('native-select-$key')),
        )
        .onChanged!(value);
    await tester.pump();
  }

  String? fieldError(WidgetTester tester, String key) {
    final field = tester.widget(find.byKey(ValueKey('native-$key')));
    return switch (field) {
      AmountField(:final errorText) => errorText,
      HelpTextField(:final errorText) => errorText,
      OptionPicker<String>(:final errorText) => errorText,
      _ => null,
    };
  }

  /// The newest record, once it's saved.
  Future<LocalRevision> saved(
    WidgetTester tester,
    LocalFixture f,
    String mode,
  ) async {
    late LocalRevision r;
    await tester.runAsync(() async {
      r = (await f.store.snapshot()).current.lastWhere(
        (x) => x.values['sharedMode'] == mode,
      );
    });
    return r;
  }

  Future<void> save(WidgetTester tester) async {
    await localTap(tester, submit());
    expect(find.textContaining('Step 2 of 2'), findsOneWidget);
    await localTap(tester, submit());
    expect(find.byKey(const ValueKey('private-done')), findsOneWidget);
  }

  testWidgets('Add to my Money sends the same command as before', (
    tester,
  ) async {
    final (f, controller, wallet) = await open(tester);
    try {
      await form(tester, controller, dinner, 'bill');
      expect(find.text('Add to my Money'), findsOneWidget);
      await pick(tester, 'account', wallet);
      await save(tester);
      final r = await saved(tester, f, 'bill');
      expect(r.values, {
        'name': 'Shared bill · Dinner',
        'date': date,
        'sharedMode': 'bill',
        'sharedAccounting': '2',
        'sharedGroup': groupId,
        'sharedKey': dinner,
        'sharedRevision': 'rev-dinner',
        'fundingAmount': '3000.00',
        'shareAmount': '1000.00',
        'account': wallet,
        'category': 'category-food',
        'reason': '',
        'funding': 'cash',
        'acknowledge': 'false',
        'acknowledgeFunding': 'false',
      });
    } finally {
      await close(tester, f, controller);
    }
  });

  testWidgets('with nothing paid, no account is asked for', (tester) async {
    final (f, controller, _) = await open(tester);
    try {
      await form(tester, controller, lunch, 'bill');
      expect(find.byKey(const ValueKey('native-select-account')), findsNothing);
      await save(tester);
      final r = await saved(tester, f, 'bill');
      expect(r.values['account'], '');
      expect(r.values['fundingAmount'], '0.00');
    } finally {
      await close(tester, f, controller);
    }
  });

  testWidgets('paying with no account says so on the field', (tester) async {
    final (f, controller, _) = await open(tester);
    try {
      await form(tester, controller, dinner, 'bill');
      await localTap(tester, submit());
      expect(fieldError(tester, 'select-account'), 'Choose an account.');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Step 1 of 2'), findsOneWidget);
    } finally {
      await close(tester, f, controller);
    }
  });

  testWidgets('below zero asks only once the rule does, on the account', (
    tester,
  ) async {
    final (f, controller, wallet) = await open(tester, balance: '100.00');
    try {
      await form(tester, controller, dinner, 'bill');
      expect(
        find.byKey(const ValueKey('native-select-acknowledge')),
        findsNothing,
      );
      await pick(tester, 'account', wallet);
      await localTap(tester, submit());
      expect(
        fieldError(tester, 'select-account'),
        contains('takes Wallet below zero'),
      );
      await pick(tester, 'acknowledge', 'true');
      await save(tester);
      expect((await saved(tester, f, 'bill')).values['acknowledge'], 'true');
    } finally {
      await close(tester, f, controller);
    }
  });

  testWidgets('a saved purchase fills and locks what the rule insists on', (
    tester,
  ) async {
    final (f, controller, wallet) = await open(tester);
    try {
      late String purchase;
      await tester.runAsync(() async {
        purchase = await f.post('expense', {
          'name': 'Dinner out',
          'account': wallet,
          'amount': '3000.00',
          'category': 'category-food',
        });
        await controller.reload();
      });
      await form(tester, controller, dinner, 'bill');
      await pick(tester, 'existing', purchase);
      expect(find.byKey(const ValueKey('native-fundingAmount')), findsNothing);
      expect(find.byKey(const ValueKey('native-date')), findsNothing);
      await localTap(tester, submit());
      expect(
        fieldError(tester, 'reason'),
        'Say why you’re changing your record.',
      );
      await enter(tester, 'reason', 'It was this dinner');
      await save(tester);
      final r = await saved(tester, f, 'bill');
      expect(r.values['source'], purchase);
      expect(r.values['sourceVersion'], '1');
      expect(r.values['account'], wallet);
      expect(r.previous, purchase);
    } finally {
      await close(tester, f, controller);
    }
  });

  testWidgets('hidden amounts stay hidden in the pickers', (tester) async {
    final (f, controller, wallet) = await open(tester);
    try {
      controller.privacyHidden = () => true;
      await tester.runAsync(() async {
        await f.post('expense', {
          'name': 'Dinner out',
          'account': wallet,
          'amount': '3000.00',
          'category': 'category-food',
        });
        await controller.reload();
      });
      final hub = HiddenHub(session, FakeWriter(), [household()]);
      await form(tester, controller, dinner, 'bill', using: hub);
      final labels = tester
          .widget<OptionPicker<String>>(
            find.byKey(const ValueKey('native-select-existing')),
          )
          .options
          .map((o) => o.label);
      expect(labels.where((l) => l.contains('₱')), isEmpty);
      expect(labels.where((l) => l.contains('Dinner out')), isNotEmpty);
    } finally {
      await close(tester, f, controller);
    }
  });

  testWidgets('a payment asks for no category and no part', (tester) async {
    final (f, controller, wallet) = await open(tester);
    try {
      await form(tester, controller, paid, 'payment');
      expect(find.byKey(const ValueKey('native-shareAmount')), findsNothing);
      expect(
        find.byKey(const ValueKey('native-select-category')),
        findsNothing,
      );
      expect(
        find.textContaining('What you received', findRichText: true),
        findsOneWidget,
      );
      await pick(tester, 'account', wallet);
      await save(tester);
      final r = await saved(tester, f, 'payment');
      expect(r.values['direction'], 'in');
      expect(r.values['shareAmount'], '0.00');
      expect(r.values['fundingAmount'], '500.00');
    } finally {
      await close(tester, f, controller);
    }
  });

  testWidgets('counting a payment fixes the amount from the user’s record', (
    tester,
  ) async {
    final (f, controller, wallet) = await open(tester);
    try {
      await form(tester, controller, paid, 'payment');
      await enter(tester, 'fundingAmount', '480.00');
      await pick(tester, 'account', wallet);
      await save(tester);
      final payment = await saved(tester, f, 'payment');
      await form(tester, controller, paid, 'clear');
      expect(find.text('Count it in my group balance'), findsOneWidget);
      expect(find.byKey(const ValueKey('native-fundingAmount')), findsNothing);
      await save(tester);
      final r = await saved(tester, f, 'clear');
      // The group says 500.00; the rule insists on the user's own record.
      expect(r.values['fundingAmount'], '480.00');
      expect(r.values['paymentSource'], payment.id);
      expect(r.values['account'], '');
    } finally {
      await close(tester, f, controller);
    }
  });

  testWidgets('a refund on a bill not in Money asks for no category', (
    tester,
  ) async {
    final (f, controller, wallet) = await open(tester);
    try {
      await form(tester, controller, refund, 'refund');
      expect(
        find.byKey(const ValueKey('native-select-category')),
        findsNothing,
      );
      await pick(tester, 'account', wallet);
      await save(tester);
      final r = await saved(tester, f, 'refund');
      expect(r.values['coverage'], 'clearing');
      expect(r.values['billSource'], dinner);
      expect(r.values['billRevision'], 'rev-dinner');
    } finally {
      await close(tester, f, controller);
    }
  });

  testWidgets('changing what you paid asks first, on the field', (
    tester,
  ) async {
    final (f, controller, wallet) = await open(tester);
    try {
      await form(tester, controller, dinner, 'bill');
      await pick(tester, 'account', wallet);
      await save(tester);
      await form(tester, controller, dinner, 'bill');
      expect(find.text('Review my record'), findsOneWidget);
      await enter(tester, 'fundingAmount', '2500.00');
      await enter(tester, 'reason', 'I paid less');
      await localTap(tester, submit());
      expect(
        fieldError(tester, 'fundingAmount'),
        'You’re changing what you paid. Confirm that’s right.',
      );
      await pick(tester, 'acknowledgeFunding', 'true');
      await save(tester);
      final r = await saved(tester, f, 'bill');
      expect(r.values['acknowledgeFunding'], 'true');
      expect(r.values['fundingAmount'], '2500.00');
    } finally {
      await close(tester, f, controller);
    }
  });

  testWidgets('a saved purchase that changed says so on the page', (
    tester,
  ) async {
    final (f, controller, _) = await open(tester);
    try {
      await tester.runAsync(
        () => f.store.saveDraft('shared-purchase:$dinner', dinner, {
          'privateSource': 'gone',
          'group': groupId,
          'bill': dinner,
        }),
      );
      await form(tester, controller, dinner, 'bill');
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.textContaining('The purchase you saved changed.'),
        findsOneWidget,
      );
      expect(submit(), findsNothing);
    } finally {
      await close(tester, f, controller);
    }
  });

  testWidgets('with no connection it stays on Review, in plain words', (
    tester,
  ) async {
    final (f, controller, wallet) = await open(tester);
    try {
      await tester.runAsync(() async {
        await f.store.stageConnection(
          newLocalId(),
          'synthetic@example.test',
          newLocalId(),
        );
        await f.store.db.execute(
          "UPDATE connected_profile SET phase='connected'",
        );
        await controller.reload();
      });
      var syncs = 0;
      controller.syncLatest = () async => syncs++;
      await form(tester, controller, dinner, 'bill');
      expect(syncs, 1, reason: 'It starts from the latest records');
      await pick(tester, 'account', wallet);
      await localTap(tester, submit());
      await localTap(tester, submit());
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Couldn’t check your latest records'), findsOneWidget);
      expect(find.textContaining('Sync now before'), findsNothing);
      expect(find.textContaining('Step 2 of 2'), findsOneWidget);
      expect(find.text('Sync and save'), findsOneWidget);
    } finally {
      await close(tester, f, controller);
    }
  });

  group('Keep my record as it is', () {
    Future<(FakeHub, FakeWriter)> keep(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final writer = FakeWriter();
      final hub = FakeHub(session, writer, [household()]);
      addTearDown(hub.dispose);
      await tester.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: SalapiyaTheme.build(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showKeepRecord(
                  context,
                  hub,
                  household(),
                  dinner,
                  LocalRevision(
                    id: 'mine',
                    actionId: 'mine',
                    kind: 'expense',
                    change: 'create',
                    date: date,
                    title: 'Shared bill · Dinner',
                    amount: BigInt.zero,
                    values: const {},
                    postings: const [],
                    number: 1,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (hub, writer);
    }

    Future<void> confirm(WidgetTester tester) async {
      await tester.tap(find.text('Keep my record'));
      await tester.pumpAndSettle();
    }

    Future<void> reason(WidgetTester tester, String text) async {
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('keep-reason')),
          matching: find.byType(EditableText),
        ),
        text,
      );
      await tester.pump();
    }

    testWidgets('a reason is needed, on its field', (tester) async {
      final (_, writer) = await keep(tester);
      await confirm(tester);
      expect(find.text('Say why it stays as it is.'), findsOneWidget);
      expect(writer.kept, isEmpty);
    });

    testWidgets('a lost answer repeats the same review', (tester) async {
      final (_, writer) = await keep(tester);
      await reason(tester, 'Still right');
      writer.keepFails = Exception('no answer');
      await confirm(tester);
      expect(find.text(lostTitle), findsOneWidget);
      await confirm(tester);
      expect(writer.kept.length, 2);
      expect(writer.kept.toSet().length, 1);
    });

    testWidgets('a refusal is a new review next time', (tester) async {
      final (_, writer) = await keep(tester);
      await reason(tester, 'Still right');
      writer.keepFails = const LocalRuleException(
        'Private source or group evidence changed',
      );
      await confirm(tester);
      expect(
        find.text('Your record or this bill changed. Check it and try again.'),
        findsOneWidget,
      );
      writer.keepFails = null;
      await confirm(tester);
      expect(writer.kept.toSet().length, 2);
    });

    testWidgets('offline it says so, and sends nothing', (tester) async {
      final (_, writer) = await keep(tester);
      writer.online = false;
      await reason(tester, 'Still right');
      await confirm(tester);
      expect(find.textContaining('needs a connection'), findsOneWidget);
      expect(writer.kept, isEmpty);
    });
  });
}

const lostTitle = 'We couldn’t tell if this reached the group';
