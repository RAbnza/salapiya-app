import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/prototype/scenarios.dart';
import 'package:salapiya/shared/shared_bill_form.dart';
import 'package:salapiya/shared/shared_data.dart';
import 'package:salapiya/shared/shared_domain.dart';
import 'package:salapiya/shared/shared_group_forms.dart';
import 'package:salapiya/shared/shared_hub.dart';
import 'package:salapiya/shared/shared_pages.dart';
import 'package:salapiya/shared/shared_payment_form.dart';

const a = '10000000-0000-4000-8000-000000000001';
const b = '10000000-0000-4000-8000-000000000002';
const c = '10000000-0000-4000-8000-000000000003';
const actor = 'me';
const today = '2026-10-31';

/// Records what a form sends, and answers as a test asks.
class FakeWriter implements SharedWriter {
  final sent = <(String, String, SharedJson, int, String?)>[];
  final retried = <String>[];
  final drafts = <String, SharedJson>{};
  final discarded = <String>[];

  /// Thrown by the next [submit], once.
  Object? failNext;

  /// Thrown by each [retry] until it's cleared.
  Object? retryFails;
  SharedJson? invitation;
  var reviews = 0;
  @override
  String? get actor => 'me';
  @override
  bool online = true;
  @override
  Future<String> submit(
    String group,
    String op,
    SharedJson values, {
    int version = 0,
    String? id,
  }) async {
    sent.add((group, op, values, version, id));
    final fail = failNext;
    failNext = null;
    if (fail != null) throw fail;
    return id ?? 'new';
  }

  @override
  Future<void> retry(String id) async {
    retried.add(id);
    final fail = retryFails;
    if (fail != null) throw fail;
  }

  @override
  Future<SharedJson> reviewInvitation(String code) async {
    reviews++;
    return invitation!;
  }

  @override
  Future<void> draft(String id, String group, SharedJson values) async =>
      drafts[id] = {...values, 'group': group};
  @override
  Future<SharedJson?> readDraft(String id) async => drafts[id];
  @override
  Future<void> discardDraft(String id) async {
    drafts.remove(id);
    discarded.add(id);
  }
}

class FakeHub extends SharedHub {
  FakeHub(super.session, this.writer, this.groups, {this.draftRows = const []});
  final FakeWriter writer;
  List<SharedGroup> groups;
  List<SharedJson> draftRows;
  @override
  SharedSource source() => SharedSource(
    today: today,
    groups: groups,
    loaded: true,
    connected: true,
    online: writer.online,
    complete: true,
    hidden: false,
    amount: (v) => '₱${phpDecimal(v)}',
    writer: writer,
    profileName: 'Ana',
    actor: actor,
    drafts: draftRows,
  );
}

SharedJson person(String name, {String? user, bool active = true}) => {
  'name': name,
  'user': user,
  'kind': user == null ? 'manual' : 'registered',
  'active': active,
};

SharedGroup makeGroup({
  String id = 'g1',
  String name = 'Household',
  int version = 7,
  SharedJson bills = const {},
  bool archived = false,
}) => SharedGroup({
  'id': id,
  'name': name,
  'owner': a,
  'version': version,
  'complete': true,
  'archived': archived,
  'people': {
    a: person('Ana', user: actor),
    b: person('Ben', user: 'ben'),
    c: person('Cy', user: 'cy'),
  },
  'bills': bills,
  'settlements': <String, dynamic>{},
  'activity': const [],
});

const equalBill = {
  'x': {
    'creator': a,
    'revisions': [
      {
        'id': 'rev-1',
        'name': 'Dinner',
        'date': '2026-10-10',
        'total': '30000',
        'paid': {a: '30000', b: '0', c: '0'},
        'shares': {a: '10000', b: '10000', c: '10000'},
        'method': 'equal',
      },
    ],
    'refunds': <dynamic>[],
  },
};

/// A group where the user (Ben) owes Ana ₱100.00 on one bill.
SharedGroup owing({bool asOwner = true}) => SharedGroup({
  ...makeGroup(bills: equalBill).data,
  'owner': asOwner ? b : a,
  'people': {
    a: person('Ana', user: 'ana'),
    b: person('Ben', user: actor),
    c: person('Cy', user: 'cy'),
  },
});

/// A group with payments waiting for the user (Ana).
SharedGroup paying({bool manualRecipient = false, int version = 7}) =>
    SharedGroup({
      ...makeGroup(version: version).data,
      'people': {
        a: person('Ana', user: actor),
        b: person('Ben', user: 'ben'),
        c: manualRecipient ? person('Lola') : person('Cy', user: 'cy'),
      },
      'settlements': {
        'in': {
          'sender': b,
          'recipient': a,
          'amount': '1000',
          'date': '2026-10-29',
          'state': 'pending',
          'allocations': <String, dynamic>{},
          'advance': '1000',
          'events': const [],
        },
        'manual': {
          'sender': b,
          'recipient': c,
          'amount': '500',
          'date': '2026-10-29',
          'state': 'pending',
          'allocations': <String, dynamic>{},
          'advance': '500',
          'events': const [],
        },
      },
    });

void main() {
  late PrototypeSession session;
  setUp(() => session = PrototypeSession());
  tearDown(() => session.dispose());

  group('sweep', () {
    const long = 'A participant with a deliberately long display name';
    SharedGroup roomy() => SharedGroup({
      ...makeGroup(bills: equalBill).data,
      'people': {
        a: person(long, user: actor),
        b: person('$long too', user: 'ben'),
        c: person('Cy', user: 'cy'),
      },
    });
    for (final (platform, width) in const [
      (TargetPlatform.android, 320.0),
      (TargetPlatform.android, 412.0),
      (TargetPlatform.windows, 720.0),
      (TargetPlatform.windows, 1200.0),
    ]) {
      for (final text in [1.0, 2.0]) {
        testWidgets('forms at ${platform.name} $width, $text', (tester) async {
          tester.view.physicalSize = Size(width, 4000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final g = roomy();
          final hub = FakeHub(session, FakeWriter(), [g]);
          addTearDown(hub.dispose);
          for (final form in <Widget>[
            SharedBillForm(hub: hub, group: g),
            SharedBillForm(hub: hub, group: g, bill: 'x'),
            SharedRefundForm(hub: hub, group: g, bill: 'x'),
          ]) {
            await tester.pumpWidget(
              MaterialApp(
                themeAnimationDuration: Duration.zero,
                theme: SalapiyaTheme.build(
                  Brightness.light,
                  platform: platform,
                ),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 4000),
                    textScaler: TextScaler.linear(text),
                  ),
                  child: form,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            // Split between payers and exact parts open more fields.
            final payers = find.byKey(const ValueKey('shared-payers'));
            if (payers.evaluate().isNotEmpty) {
              await tester.tap(payers);
              await tester.pump();
              await tester.tap(find.text('Exact amounts'));
              await tester.pump();
              expect(tester.takeException(), isNull);
            }
            await tester.pumpWidget(const SizedBox.shrink());
          }
        });
      }
    }
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    final name = platform.name;

    Future<void> open(WidgetTester tester, Widget form) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: SalapiyaTheme.build(Brightness.light, platform: platform),
          home: form,
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder field(String key) => find.byKey(ValueKey('native-$key'));
    Future<void> enter(WidgetTester tester, String key, String text) async {
      await tester.enterText(
        find.descendant(of: field(key), matching: find.byType(TextField)),
        text,
      );
      await tester.pump();
    }

    Future<void> submit(WidgetTester tester) async {
      final button = find.byKey(const ValueKey('shared-submit'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    Future<void> launcher(
      WidgetTester tester,
      Future<void> Function(BuildContext) run,
    ) async {
      await open(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => run(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('$name: All of it sends the same command as the old form', (
      tester,
    ) async {
      final writer = FakeWriter();
      final g = owing();
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await open(tester, SharedPaymentForm(hub: hub, group: g, recipient: a));
      expect(find.textContaining('All of it · ₱100.00'), findsOneWidget);
      await submit(tester);
      expect(find.text('Waiting for Ana to confirm'), findsOneWidget);
      expect(find.textContaining('nothing is left between'), findsOneWidget);
      await submit(tester);
      final (group, op, values, version, id) = writer.sent.single;
      expect(group, 'g1');
      expect(op, 'report');
      expect(version, 7);
      expect(id, isNotNull);
      expect(values.keys.toSet(), {
        'sender',
        'recipient',
        'date',
        'amount',
        'mode',
        'allocations',
        'acknowledge',
      });
      expect(values['sender'], b);
      expect(values['recipient'], a);
      expect(values['amount'], '10000');
      expect(values['mode'], 'full');
      expect(values['allocations'], isEmpty);
      expect(values['acknowledge'], false);
      expect(find.text('Saved. Waiting for the group.'), findsOneWidget);
    });

    testWidgets('$name: Part of it can be less, and says what’s left', (
      tester,
    ) async {
      final writer = FakeWriter();
      final g = owing();
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await open(tester, SharedPaymentForm(hub: hub, group: g, recipient: a));
      await tester.tap(find.text('Part of it'));
      await tester.pump();
      await submit(tester);
      expect(find.text('Enter the amount.'), findsOneWidget);
      await enter(tester, 'amount', '40.00');
      await submit(tester);
      expect(find.textContaining('still owe Ana ₱60.00'), findsOneWidget);
      await submit(tester);
      expect(writer.sent.single.$3['mode'], 'custom');
      expect(writer.sent.single.$3['amount'], '4000');
    });

    testWidgets('$name: more than what’s owed asks before it counts', (
      tester,
    ) async {
      final writer = FakeWriter();
      final g = owing();
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await open(tester, SharedPaymentForm(hub: hub, group: g, recipient: a));
      await tester.tap(find.text('Part of it'));
      await tester.pump();
      await enter(tester, 'amount', '120.00');
      expect(find.text('That’s ₱20.00 more than what’s owed'), findsOneWidget);
      await submit(tester);
      expect(
        find.text('Confirm that’s right, or change the amount.'),
        findsOneWidget,
      );
      expect(writer.sent, isEmpty);
      await tester.tap(find.text('That is right'));
      await tester.pump();
      await submit(tester);
      expect(find.text('Paid ahead'), findsOneWidget);
      await submit(tester);
      expect(writer.sent.single.$3['acknowledge'], true);
      expect(writer.sent.single.$3['amount'], '12000');
    });

    testWidgets('$name: Choose bills sends what went against each', (
      tester,
    ) async {
      final writer = FakeWriter();
      final g = owing();
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await open(tester, SharedPaymentForm(hub: hub, group: g, recipient: a));
      await tester.tap(find.text('Choose bills'));
      await tester.pump();
      await submit(tester);
      expect(
        find.text('Enter an amount on at least one bill.'),
        findsOneWidget,
      );
      await enter(tester, 'allocation:x', '30.00');
      await submit(tester);
      await submit(tester);
      final values = writer.sent.single.$3;
      expect(values['mode'], 'selected');
      expect(values['amount'], '3000');
      expect(values['allocations'], {
        'x': {'amount': '3000', 'revision': 'rev-1'},
      });
      expect(values['acknowledge'], false);
    });

    testWidgets('$name: you can only log your own, unless you own the group '
        'and they’re not registered', (tester) async {
      final writer = FakeWriter();
      final g = owing(asOwner: false);
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await open(tester, SharedPaymentForm(hub: hub, group: g));
      expect(find.byKey(const ValueKey('native-select-sender')), findsNothing);
      await submit(tester);
      expect(find.text('Choose who was paid.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());

      final manual = SharedGroup({
        ...makeGroup().data,
        'people': {a: person('Ana', user: actor), b: person('Lola')},
      });
      final owner = FakeHub(session, FakeWriter(), [manual]);
      addTearDown(owner.dispose);
      await open(tester, SharedPaymentForm(hub: owner, group: manual));
      expect(
        find.byKey(const ValueKey('native-select-sender')),
        findsOneWidget,
      );
    });

    testWidgets('$name: a payment works offline and says it waits', (
      tester,
    ) async {
      final writer = FakeWriter()..online = false;
      final g = owing();
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await open(tester, SharedPaymentForm(hub: hub, group: g, recipient: a));
      await submit(tester);
      expect(find.textContaining('You’re offline.'), findsOneWidget);
      await submit(tester);
      expect(writer.sent.single.$2, 'report');
    });

    testWidgets('$name: a payment draft comes back', (tester) async {
      final writer = FakeWriter()
        ..drafts['d1'] = {
          'op': 'report',
          'fields': {
            'recipient': a,
            'mode': 'custom',
            'amount': '12.00',
            'date': '2026-10-20',
          },
        };
      final g = owing();
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await open(tester, SharedPaymentForm(hub: hub, group: g, draftId: 'd1'));
      await tester.pumpAndSettle();
      await submit(tester);
      await submit(tester);
      expect(writer.sent.single.$3['amount'], '1200');
      expect(writer.sent.single.$3['date'], '2026-10-20');
      expect(writer.sent.single.$5, 'd1');
    });

    Future<void> answer(
      WidgetTester tester,
      FakeHub hub,
      SharedGroup g,
      String id,
      PaymentAnswer choice,
    ) async {
      await launcher(
        tester,
        (context) => showPaymentAnswer(context, hub, g, id, choice),
      );
    }

    testWidgets('$name: Confirm sends the same command as the old form', (
      tester,
    ) async {
      final writer = FakeWriter();
      final g = paying();
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await answer(tester, hub, g, 'in', PaymentAnswer.confirm);
      expect(find.textContaining('Ben logged ₱10.00'), findsOneWidget);
      await tester.tap(find.text('Confirm').last);
      await tester.pumpAndSettle();
      final (group, op, values, version, id) = writer.sent.single;
      expect(group, 'g1');
      expect(op, 'resolve');
      expect(version, 7);
      expect(id, isNotNull);
      expect(values, {
        'settlement': 'in',
        'state': 'confirmed',
        'reason': '',
        'acknowledge': false,
      });
    });

    testWidgets('$name: Dispute needs a reason, on its field', (tester) async {
      final writer = FakeWriter();
      final g = paying();
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await answer(tester, hub, g, 'in', PaymentAnswer.dispute);
      await tester.tap(find.text('Dispute'));
      await tester.pumpAndSettle();
      expect(find.text('Say why, so everyone can see it.'), findsOneWidget);
      expect(writer.sent, isEmpty);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('payment-reason')),
          matching: find.byType(TextField),
        ),
        'Nothing arrived',
      );
      await tester.tap(find.text('Dispute'));
      await tester.pumpAndSettle();
      expect(writer.sent.single.$3['state'], 'disputed');
      expect(writer.sent.single.$3['reason'], 'Nothing arrived');
    });

    testWidgets('$name: a person who isn’t registered needs the owner’s word', (
      tester,
    ) async {
      final writer = FakeWriter();
      final g = paying(manualRecipient: true);
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await answer(tester, hub, g, 'manual', PaymentAnswer.confirm);
      await tester.tap(find.text('Confirm').last);
      await tester.pumpAndSettle();
      expect(find.text('Tick this to record it for them.'), findsOneWidget);
      expect(writer.sent, isEmpty);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('payment-manual')),
          matching: find.byType(Checkbox),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Confirm').last);
      await tester.pumpAndSettle();
      expect(writer.sent.single.$3['acknowledge'], true);
    });

    testWidgets('$name: a lost answer on Confirm is never a second command', (
      tester,
    ) async {
      final writer = FakeWriter()..failNext = const SocketException('gone');
      final g = paying();
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await answer(tester, hub, g, 'in', PaymentAnswer.confirm);
      await tester.tap(find.text('Confirm').last);
      await tester.pumpAndSettle();
      expect(find.text(lostResponseTitle), findsOneWidget);
      await tester.tap(find.text('Confirm').last);
      await tester.pumpAndSettle();
      expect(writer.sent.length, 2);
      expect(writer.sent.first.$5, writer.sent.last.$5);
    });

    testWidgets('$name: a group that changed stops before it’s refused', (
      tester,
    ) async {
      final writer = FakeWriter();
      final g = paying();
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      hub.groups = [paying(version: 8)];
      await answer(tester, hub, g, 'in', PaymentAnswer.confirm);
      await tester.tap(find.text('Confirm').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('The group changed'), findsOneWidget);
      expect(writer.sent, isEmpty);
    });

    testWidgets('$name: a refused answer shows plainly, with a new id next', (
      tester,
    ) async {
      final writer = FakeWriter()
        ..failNext = const LocalRuleException('Invalid settlement transition');
      final g = paying();
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await answer(tester, hub, g, 'in', PaymentAnswer.confirm);
      await tester.tap(find.text('Confirm').last);
      await tester.pumpAndSettle();
      expect(
        find.text('This payment has already changed. Check it first.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Confirm').last);
      await tester.pumpAndSettle();
      expect(writer.sent.first.$5, isNot(writer.sent.last.$5));
    });

    testWidgets('$name: Share a purchase asks only what the group needs', (
      tester,
    ) async {
      final writer = FakeWriter();
      final g = makeGroup();
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await open(
        tester,
        SharedBillForm(
          hub: hub,
          group: g,
          purchase: SharedPurchase(
            id: 'p1',
            name: 'Groceries',
            date: '2026-10-20',
            total: BigInt.from(9000),
          ),
        ),
      );
      expect(field('total'), findsNothing);
      expect(find.text('₱90.00'), findsOneWidget);
      await submit(tester);
      await submit(tester);
      final (_, op, values, version, _) = writer.sent.single;
      expect(op, 'bill');
      expect(version, 7);
      expect(values.keys.toSet(), {
        'date',
        'total',
        'name',
        'paid',
        'shares',
        'method',
      });
      expect(values['paid'], {a: '9000'});
      expect(values['date'], '2026-10-20');
      expect(values['total'], '9000');
      expect(values['shares'], {a: '3000', b: '3000', c: '3000'});
      expect(writer.drafts, isEmpty);
    });

    testWidgets('$name: Add sends the same command as the old form', (
      tester,
    ) async {
      final writer = FakeWriter();
      final hub = FakeHub(session, writer, [makeGroup()]);
      addTearDown(hub.dispose);
      await open(tester, SharedBillForm(hub: hub, group: hub.groups.first));
      await enter(tester, 'name', 'Groceries');
      await enter(tester, 'total', '100.00');
      // The live split, with who gets the extra centavo.
      expect(find.text('Gets back ₱66.66'), findsOneWidget);
      expect(find.text('Owes ₱33.33'), findsNWidgets(2));
      expect(find.textContaining('₱33.34'), findsOneWidget);
      expect(find.textContaining('extra centavo goes to You'), findsOneWidget);
      await submit(tester);
      expect(find.text('Step 2 of 2 · Review'), findsOneWidget);
      expect(writer.sent, isEmpty);
      await submit(tester);
      final (group, op, values, version, id) = writer.sent.single;
      expect(group, 'g1');
      expect(op, 'bill');
      expect(version, 7);
      expect(id, isNotNull);
      expect(values.keys.toSet(), {
        'date',
        'total',
        'name',
        'paid',
        'shares',
        'method',
      });
      expect(values['total'], '10000');
      expect(values['date'], civilDate(today));
      expect(values['method'], 'equal');
      // Everyone, zeros included, as the command always carried.
      expect(values['paid'], {a: '10000', b: '0', c: '0'});
      expect(values['shares'], {a: '3334', b: '3333', c: '3333'});
      expect(find.text('Saved. Waiting for the group.'), findsOneWidget);
    });

    testWidgets('$name: errors land on their own field', (tester) async {
      final writer = FakeWriter();
      final hub = FakeHub(session, writer, [makeGroup()]);
      addTearDown(hub.dispose);
      await open(tester, SharedBillForm(hub: hub, group: hub.groups.first));
      await submit(tester);
      expect(find.text('Say what this was for.'), findsOneWidget);
      await enter(tester, 'name', 'Rent');
      await submit(tester);
      expect(find.text('Enter the total.'), findsOneWidget);
      await enter(tester, 'total', '0.00');
      await submit(tester);
      expect(find.text('Enter a total greater than zero.'), findsOneWidget);
      await enter(tester, 'total', '90.00');

      // Nobody's in: the rule's own words, on Who's in.
      for (final p in [a, b, c]) {
        await tester.tap(
          find.descendant(
            of: find.byKey(ValueKey('include-$p')),
            matching: find.byType(Checkbox),
          ),
        );
        await tester.pump();
      }
      await submit(tester);
      expect(
        find.text('Choose at least one person, up to 100.'),
        findsOneWidget,
      );
      expect(writer.sent, isEmpty);
    });

    testWidgets('$name: several payers must add up, on their field', (
      tester,
    ) async {
      final writer = FakeWriter();
      final hub = FakeHub(session, writer, [makeGroup()]);
      addTearDown(hub.dispose);
      await open(tester, SharedBillForm(hub: hub, group: hub.groups.first));
      await enter(tester, 'name', 'Taxi');
      await enter(tester, 'total', '100.00');
      await tester.tap(find.byKey(const ValueKey('shared-payers')));
      await tester.pump();
      await enter(tester, 'paid:$a', '60.00');
      expect(find.textContaining('₱40.00 left to assign'), findsOneWidget);
      await submit(tester);
      expect(
        find.text(
          'What each person paid and each person’s part must each add up to the total.',
        ),
        findsOneWidget,
      );
      await enter(tester, 'paid:$b', '40.00');
      expect(find.textContaining('matches the total'), findsOneWidget);
      await submit(tester);
      await submit(tester);
      expect(writer.sent.single.$3['paid'], {a: '6000', b: '4000', c: '0'});
    });

    testWidgets('$name: Who’s in shows what each person ends up with', (
      tester,
    ) async {
      final writer = FakeWriter();
      final g = SharedGroup({
        ...makeGroup().data,
        'people': {
          ...makeGroup().people,
          '10000000-0000-4000-8000-000000000004': person('Dee', user: 'dee'),
        },
      });
      const d = '10000000-0000-4000-8000-000000000004';
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await open(tester, SharedBillForm(hub: hub, group: g));
      await enter(tester, 'name', 'Dinner');
      await enter(tester, 'total', '1000.00');
      await tester.tap(find.byKey(const ValueKey('shared-payers')));
      await tester.pump();

      // Half entered: no figure that would turn out wrong, and it says why.
      await enter(tester, 'paid:$a', '100');
      expect(find.text('Part ₱250.00'), findsNWidgets(4));
      expect(find.textContaining('Owes'), findsNothing);
      expect(
        find.text(
          'What each person owes shows once Who paid adds up to the total.',
        ),
        findsOneWidget,
      );

      // As in the owner's review: ₱250 each, paid 100, 200, 300 and 400.
      await enter(tester, 'paid:$b', '200');
      await enter(tester, 'paid:$c', '300');
      await enter(tester, 'paid:$d', '400');
      Finder result(String person, String text) => find.descendant(
        of: find.byKey(ValueKey('result-$person')),
        matching: find.text(text),
      );
      expect(result(a, 'Owes ₱150.00'), findsOneWidget);
      expect(result(b, 'Owes ₱50.00'), findsOneWidget);
      expect(result(c, 'Gets back ₱50.00'), findsOneWidget);
      expect(result(d, 'Gets back ₱150.00'), findsOneWidget);
      expect(find.textContaining('shows once Who paid'), findsNothing);

      // Paying without being in: all of it comes back, and the parts redo.
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('include-$d')),
          matching: find.byType(Checkbox),
        ),
      );
      await tester.pump();
      expect(result(d, 'Gets back ₱400.00'), findsOneWidget);
      expect(result(a, 'Owes ₱233.34'), findsOneWidget);

      await submit(tester);
      await submit(tester);
      final values = writer.sent.single.$3;
      expect(values['paid'], {a: '10000', b: '20000', c: '30000', d: '40000'});
      expect(values['shares'], {a: '33334', b: '33333', c: '33333'});
    });

    testWidgets('$name: exact parts go through, and must add up', (
      tester,
    ) async {
      final writer = FakeWriter();
      final hub = FakeHub(session, writer, [makeGroup()]);
      addTearDown(hub.dispose);
      await open(tester, SharedBillForm(hub: hub, group: hub.groups.first));
      await enter(tester, 'name', 'Internet');
      await enter(tester, 'total', '100.00');
      await tester.tap(find.text('Exact amounts'));
      await tester.pump();
      await enter(tester, 'share:$a', '70.00');
      await enter(tester, 'share:$b', '20.00');
      await submit(tester);
      expect(find.textContaining('must each add up'), findsOneWidget);
      await enter(tester, 'share:$c', '10.00');
      await submit(tester);
      await submit(tester);
      final values = writer.sent.single.$3;
      expect(values['method'], 'exact');
      expect(values['shares'], {a: '7000', b: '2000', c: '1000'});
    });

    testWidgets('$name: Correct keeps the bill’s split and its date', (
      tester,
    ) async {
      final writer = FakeWriter();
      final g = makeGroup(bills: equalBill);
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await open(tester, SharedBillForm(hub: hub, group: g, bill: 'x'));
      await enter(tester, 'total', '300.00');
      await submit(tester);
      expect(find.text('Say why you’re changing this.'), findsOneWidget);
      await enter(tester, 'reason', 'Added a side');
      await submit(tester);
      await submit(tester);
      final (_, op, values, version, _) = writer.sent.single;
      expect(op, 'correct');
      expect(version, 7);
      expect(values['method'], 'equal');
      expect(values['date'], '2026-10-10');
      expect(values['bill'], 'x');
      expect(values['revision'], 'rev-1');
      expect(values['reason'], 'Added a side');
      expect(values['shares'], {a: '10000', b: '10000', c: '10000'});
    });

    testWidgets('$name: a change that needs a connection says so at Review', (
      tester,
    ) async {
      final writer = FakeWriter()..online = false;
      final g = makeGroup(bills: equalBill);
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await open(tester, SharedBillForm(hub: hub, group: g, bill: 'x'));
      await enter(tester, 'reason', 'Fixing it');
      await submit(tester);
      expect(
        find.text('This needs a connection. What you entered is kept.'),
        findsOneWidget,
      );
      final save = tester.widget<FilledButton>(
        find.byKey(const ValueKey('shared-submit')),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('$name: a new bill queues offline and says it waits', (
      tester,
    ) async {
      final writer = FakeWriter()..online = false;
      final hub = FakeHub(session, writer, [makeGroup()]);
      addTearDown(hub.dispose);
      await open(tester, SharedBillForm(hub: hub, group: hub.groups.first));
      await enter(tester, 'name', 'Water');
      await enter(tester, 'total', '30.00');
      await submit(tester);
      expect(find.textContaining('You’re offline.'), findsOneWidget);
      await submit(tester);
      expect(writer.sent.single.$2, 'bill');
    });

    testWidgets('$name: a lost answer checks the same id, never a second '
        'command', (tester) async {
      final writer = FakeWriter()..failNext = const SocketException('gone');
      final g = makeGroup(bills: equalBill);
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await open(tester, SharedBillForm(hub: hub, group: g, bill: 'x'));
      await enter(tester, 'reason', 'Fixing it');
      await submit(tester);
      await submit(tester);
      expect(find.text(lostResponseTitle), findsOneWidget);
      final id = writer.sent.single.$5!;
      writer.retryFails = const SocketException('still gone');
      final again = find.byKey(const ValueKey('shared-check-again'));
      await tester.ensureVisible(again);
      await tester.tap(again);
      await tester.pumpAndSettle();
      expect(find.text(lostResponseTitle), findsOneWidget);
      writer.retryFails = null;
      await tester.tap(again);
      await tester.pumpAndSettle();
      expect(writer.retried, [id, id]);
      expect(writer.sent.length, 1);
      expect(find.text('Saved. The group has it.'), findsOneWidget);
    });

    testWidgets('$name: a refusal shows plainly, and the next try is a new '
        'command', (tester) async {
      final writer = FakeWriter()
        ..failNext = const LocalRuleException(
          'Group changed; refresh and review',
        );
      final g = makeGroup(bills: equalBill);
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await open(tester, SharedBillForm(hub: hub, group: g, bill: 'x'));
      await enter(tester, 'reason', 'Fixing it');
      await submit(tester);
      await submit(tester);
      expect(
        find.text(
          'The group changed while you were working. Check it and try again.',
        ),
        findsOneWidget,
      );
      await submit(tester);
      expect(writer.sent.length, 2);
      expect(writer.sent.first.$5, isNot(writer.sent.last.$5));
    });

    testWidgets('$name: a group that changed stops before it’s refused', (
      tester,
    ) async {
      final writer = FakeWriter();
      final g = makeGroup(bills: equalBill);
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await open(tester, SharedBillForm(hub: hub, group: g, bill: 'x'));
      await enter(tester, 'reason', 'Fixing it');
      await submit(tester);
      hub.groups = [makeGroup(bills: equalBill, version: 8)];
      await submit(tester);
      expect(find.text('This group changed'), findsOneWidget);
      expect(writer.sent, isEmpty);
    });

    testWidgets('$name: New asks which group when there are several', (
      tester,
    ) async {
      final writer = FakeWriter();
      final hub = FakeHub(session, writer, [
        makeGroup(),
        makeGroup(id: 'g2', name: 'Trip', version: 3),
      ]);
      addTearDown(hub.dispose);
      await open(tester, SharedBillForm(hub: hub));
      expect(find.byKey(const ValueKey('native-select-group')), findsOneWidget);
    });

    testWidgets('$name: Refund sends the rule’s two axes, within their room', (
      tester,
    ) async {
      final writer = FakeWriter();
      final g = makeGroup(bills: equalBill);
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await open(tester, SharedRefundForm(hub: hub, group: g, bill: 'x'));
      await enter(tester, 'total', '90.00');
      await enter(tester, 'reason', 'Returned a dish');
      await enter(tester, 'paid:$a', '90.00');
      await enter(tester, 'share:$a', '150.00');
      await submit(tester);
      expect(find.textContaining('more than what’s left'), findsOneWidget);
      final equal = find.byKey(const ValueKey('shared-refund-equal'));
      await tester.ensureVisible(equal);
      await tester.tap(equal);
      await tester.pump();
      await submit(tester);
      await submit(tester);
      final (_, op, values, _, _) = writer.sent.single;
      expect(op, 'refund');
      expect(values['bill'], 'x');
      expect(values['revision'], 'rev-1');
      expect(values['received'], {a: '9000', b: '0', c: '0'});
      expect(values['credits'], {a: '3000', b: '3000', c: '3000'});
    });

    testWidgets('$name: a refund can’t predate its bill', (tester) async {
      final writer = FakeWriter();
      final bills = jsonDecode(jsonEncode(equalBill)) as Map<String, dynamic>;
      bills['x']['revisions'][0]['date'] = '2099-01-01';
      final g = makeGroup(bills: bills);
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await open(tester, SharedRefundForm(hub: hub, group: g, bill: 'x'));
      await enter(tester, 'total', '10.00');
      await submit(tester);
      expect(
        find.text('A refund can’t be dated before its bill.'),
        findsOneWidget,
      );
    });

    testWidgets('$name: a draft comes back, and can be discarded', (
      tester,
    ) async {
      final writer = FakeWriter()
        ..drafts['d1'] = {
          'op': 'bill',
          'fields': {
            'name': 'Saved rent',
            'total': '50.00',
            'paid:$b': '50.00',
            'include:$c': 'no',
          },
        };
      final hub = FakeHub(session, writer, [makeGroup()]);
      addTearDown(hub.dispose);
      await open(
        tester,
        SharedBillForm(hub: hub, group: hub.groups.first, draftId: 'd1'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved rent'), findsOneWidget);
      await submit(tester);
      await submit(tester);
      final values = writer.sent.single.$3;
      expect(values['paid'], {a: '0', b: '5000', c: '0'});
      expect((values['shares'] as Map).containsKey(c), isFalse);
      expect(writer.sent.single.$5, 'd1');
      await hub.source().writer.discardDraft('d1');
      expect(writer.discarded, ['d1']);
    });

    testWidgets('$name: every draft opens or says why it can’t', (
      tester,
    ) async {
      final writer = FakeWriter();
      final g = makeGroup(bills: equalBill);
      final hub = FakeHub(
        session,
        writer,
        [g],
        draftRows: [
          {
            'id': 'gone-group',
            'group_id': 'nowhere',
            'payload': jsonEncode({'op': 'bill', 'fields': <String, String>{}}),
          },
          {
            'id': 'gone-bill',
            'group_id': 'g1',
            'payload': jsonEncode({
              'op': 'bill',
              'source': 'missing',
              'fields': <String, String>{},
            }),
          },
        ],
      );
      addTearDown(hub.dispose);
      late BuildContext place;
      await open(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) {
              place = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final flows = SharedFlows(hub);
      unawaited(flows.openDraft(place, 'gone-group'));
      await tester.pumpAndSettle();
      expect(find.textContaining('isn’t on this device yet'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      unawaited(flows.openDraft(place, 'gone-bill'));
      await tester.pumpAndSettle();
      expect(find.textContaining('isn’t here any more'), findsOneWidget);
      await tester.tap(find.text('Discard draft'));
      await tester.pumpAndSettle();
      expect(writer.discarded, ['gone-bill']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: Create and Join say they need a connection first', (
      tester,
    ) async {
      final writer = FakeWriter()..online = false;
      final hub = FakeHub(session, writer, const []);
      addTearDown(hub.dispose);
      await launcher(
        tester,
        (context) => SharedFlows(hub).createGroup(context),
      );
      expect(find.text('This needs a connection'), findsOneWidget);
      expect(find.text('Add group'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('This needs a connection'), findsOneWidget);
    });

    testWidgets('$name: a draft for someone no longer here still opens', (
      tester,
    ) async {
      final writer = FakeWriter()
        ..drafts['d2'] = {
          'op': 'report',
          'fields': {
            'sender': 'gone',
            'recipient': 'gone',
            'mode': 'selected',
            'amount': '5.00',
          },
        };
      final g = owing();
      final hub = FakeHub(session, writer, [g]);
      addTearDown(hub.dispose);
      await open(tester, SharedPaymentForm(hub: hub, group: g, draftId: 'd2'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await submit(tester);
      expect(find.text('Choose who was paid.'), findsOneWidget);
    });

    testWidgets('$name: Create repeats the same command after a lost answer', (
      tester,
    ) async {
      final writer = FakeWriter()..failNext = const SocketException('gone');
      final hub = FakeHub(session, writer, const []);
      addTearDown(hub.dispose);
      await launcher(tester, (context) => showCreateGroup(context, hub));
      await tester.tap(find.text('Add group'));
      await tester.pumpAndSettle();
      expect(find.text('Name your group.'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('group-name')),
          matching: find.byType(TextField),
        ),
        'Trip',
      );
      await tester.tap(find.text('Add group'));
      await tester.pumpAndSettle();
      expect(find.text(lostResponseTitle), findsOneWidget);
      await tester.tap(find.text('Add group'));
      await tester.pumpAndSettle();
      expect(writer.sent.length, 2);
      final (g1, op, v1, _, id1) = writer.sent.first;
      final (g2, _, v2, _, id2) = writer.sent.last;
      expect(op, 'create');
      expect(g1, g2);
      expect(id1, id2);
      expect(v1, v2);
      expect(v1.keys.toSet(), {'name', 'display', 'participant'});
      expect(hub.selected, g1);
    });

    testWidgets('$name: Join can be cancelled, and a lost answer doesn’t '
        'review a used code', (tester) async {
      final writer = FakeWriter()
        ..invitation = {
          'disclosure': 'Joining shares the group history with you.',
          'document': makeGroup().data,
        };
      final hub = FakeHub(session, writer, const []);
      addTearDown(hub.dispose);
      await launcher(tester, (context) => showJoinGroup(context, hub));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('group-code')),
          matching: find.byType(TextField),
        ),
        'g1.token',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Join Household?'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      // Back on the form, with nothing called a problem.
      expect(find.byKey(const ValueKey('group-code')), findsOneWidget);
      expect(writer.sent, isEmpty);
      expect(find.byType(SnackBar), findsNothing);

      writer.failNext = const SocketException('gone');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join group'));
      await tester.pumpAndSettle();
      expect(find.text(lostResponseTitle), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(writer.reviews, 2, reason: 'A used code can’t be reviewed again.');
      expect(writer.sent.length, 2);
      expect(writer.sent.first.$5, writer.sent.last.$5);
      expect(writer.sent.last.$2, 'accept');
      expect(writer.sent.last.$3.keys.toSet(), {
        'token',
        'consent',
        'display',
        'participant',
      });
      expect(writer.sent.last.$3['token'], 'token');
      expect(hub.selected, 'g1');
    });
  }
}

void unawaited(Future<void> future) {}
