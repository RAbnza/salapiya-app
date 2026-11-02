import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/design_system/kit/kit.dart';
import 'package:salapiya/design_system/theme.dart';
import 'package:salapiya/features/finance/presentation/shared_screen.dart';
import 'package:salapiya/local/finance_domain.dart';
import 'package:salapiya/prototype/scenarios.dart';
import 'package:salapiya/shared/shared_change_forms.dart';
import 'package:salapiya/shared/shared_data.dart';
import 'package:salapiya/shared/shared_demo.dart';
import 'package:salapiya/shared/shared_domain.dart';
import 'package:salapiya/shared/shared_history_tab.dart';
import 'package:salapiya/shared/shared_hub.dart';
import 'package:salapiya/shared/shared_people_data.dart';
import 'package:salapiya/shared/shared_person_pages.dart';
import 'package:salapiya/shared/shared_repository.dart';

import 'shared_form_test.dart' show FakeHub, FakeWriter;

const windows = TargetPlatform.windows, android = TargetPlatform.android;
const sizes = [
  (android, 320.0),
  (android, 360.0),
  (android, 412.0),
  (windows, 720.0),
  (windows, 1200.0),
  (windows, 1440.0),
];
const a = 'aaaaaaaa-0000-4000-8000-000000000001';
const b = 'aaaaaaaa-0000-4000-8000-000000000002';
const c = 'aaaaaaaa-0000-4000-8000-000000000003';
const d = 'aaaaaaaa-0000-4000-8000-000000000004';
const e = 'aaaaaaaa-0000-4000-8000-000000000005';
const today = '2026-10-31';

SharedJson person(
  String name, {
  String? user,
  bool active = true,
  String kind = 'registered',
  List<SharedJson> intervals = const [],
}) => {
  'name': name,
  'user': user,
  'kind': kind,
  'active': active,
  'intervals': intervals,
};

/// Ana owns it, Ben is a member, Cy isn't registered, Di left, and Ed's
/// account was deleted.
SharedGroup crew({
  String owner = a,
  bool archived = false,
  List<SharedJson> activity = const [],
  SharedJson bills = const {},
  int version = 4,
}) => SharedGroup({
  'id': 'g',
  'name': 'Crew',
  'owner': owner,
  'version': version,
  'complete': true,
  'archived': archived,
  'people': {
    a: person('Ana', user: 'me'),
    b: person('Ben', user: 'ben'),
    c: person('Cy', kind: 'manual'),
    d: person('Di', user: 'di', active: false),
    e: person('Deleted participant', kind: 'deleted', active: false),
  },
  'bills': bills,
  'settlements': const <String, dynamic>{},
  'activity': activity,
});

void main() {
  group('what’s offered', () {
    test('an owner of an open group', () {
      final x = groupChoices(crew(), a);
      expect(x.addPeople && x.remove && x.transfer && x.archive, isTrue);
      expect(x.restore, isFalse);
      expect(x.leave, isFalse, reason: 'A group can’t lose its owner');
      expect(x.mustHandOver, isTrue);
    });

    test('an owner of an archived group: only what the server takes', () {
      final x = groupChoices(crew(archived: true), a);
      expect(x.addPeople || x.remove || x.archive, isFalse);
      expect(x.transfer && x.restore, isTrue);
    });

    test('a member can only leave, archived or not', () {
      for (final archived in [false, true]) {
        final x = groupChoices(crew(archived: archived), b);
        expect(x.leave, isTrue);
        expect(
          x.addPeople || x.remove || x.transfer || x.archive || x.restore,
          isFalse,
        );
      }
    });

    test('someone who left, or isn’t in the group, gets nothing', () {
      expect(groupChoices(crew(), d).any, isFalse);
      expect(groupChoices(crew(), null).any, isFalse);
    });

    test('pickers list only who the server accepts', () {
      final g = crew();
      expect(removableMembers(g).map((m) => m.person), {b, c});
      expect(ownerCandidates(g).map((m) => m.person), {b});
    });

    test('an owner alone can only archive', () {
      final g = SharedGroup({
        ...crew().data,
        'people': {a: person('Ana', user: 'me')},
      });
      final x = groupChoices(g, a);
      expect(x.transfer || x.remove, isFalse);
      expect(x.archive && x.mustHandOver, isTrue);
    });

    test('what a person’s page offers', () {
      final g = crew();
      expect(memberChoices(g, a, b).remove, isTrue);
      expect(memberChoices(g, a, b).makeOwner, isTrue);
      expect(memberChoices(g, a, b).claim, isFalse);
      expect(memberChoices(g, a, c).makeOwner, isFalse, reason: 'Unregistered');
      expect(memberChoices(g, a, c).claim, isTrue);
      expect(memberChoices(g, a, a).any, isFalse);
      expect(memberChoices(g, a, d).any, isFalse);
      expect(memberChoices(g, a, e).any, isFalse);
      expect(memberChoices(g, b, c).any, isFalse, reason: 'Not the owner');
      expect(memberChoices(crew(archived: true), a, c).any, isFalse);
    });
  });

  group('invitations', () {
    SharedJson sent(String id, String at) => {
      'id': id,
      'op': 'invite',
      'at': at,
      'actor': 'me',
    };
    SharedJson intent(
      String id,
      String op,
      SharedJson values, {
      String? state,
    }) => {
      'id': id,
      'state': state ?? 'reconciled',
      'payload': jsonEncode({'op': op, 'values': values}),
    };
    final g = crew(
      activity: [
        sent('old', '2026-10-23 01:00:00+00'),
        sent('edge', '2026-10-24 01:00:00+00'),
        sent('new', '2026-10-30 01:00:00+00'),
      ],
    );

    test('seven days, up to and including the last', () {
      final rows = openInvitations(g, const [], today);
      expect(rows.map((r) => r.id), ['new', 'edge']);
      expect(rows.last.expires, today);
      expect(rows.first.email, isNull);
    });

    test('this device knows who it sent to and what it revoked', () {
      final rows = openInvitations(g, [
        intent('new', 'invite', {'email': 'ana@example.test'}),
        intent('r', 'revoke', {'invitation': 'edge'}),
      ], today);
      expect(rows.single.id, 'new');
      expect(rows.single.email, 'ana@example.test');
    });

    test('a refused revoke leaves it open', () {
      final rows = openInvitations(g, [
        intent('r', 'revoke', {'invitation': 'edge'}, state: 'review'),
      ], today);
      expect(rows.map((r) => r.id), contains('edge'));
    });
  });

  group('history', () {
    final dinner = {
      'creator': a,
      'revisions': [
        {
          'id': 'bill',
          'name': 'Dinner',
          'date': '2026-10-10',
          'total': '30000',
          'paid': {a: '30000'},
          'shares': {a: '15000', b: '15000'},
        },
        {
          'id': 'fix',
          'name': 'Dinner',
          'date': '2026-10-10',
          'total': '40000',
          'paid': {a: '40000'},
          'shares': {a: '20000', b: '20000'},
        },
      ],
      'refunds': [
        {
          'id': 'back',
          'total': '1000',
          'received': {a: '1000'},
          'credits': {b: '1000'},
        },
      ],
    };
    SharedJson event(
      String id,
      String op, {
      String at = '2026-10-10 01:00:00+00',
      String? actor = 'me',
      String? reason,
    }) => {'id': id, 'op': op, 'at': at, 'actor': actor, 'reason': reason};

    SharedGroup with_(List<SharedJson> activity) => SharedGroup({
      ...crew().data,
      'bills': {'bill': dinner},
      'settlements': {
        'p': {
          'id': 'p',
          'sender': b,
          'recipient': a,
          'amount': '5000',
          'date': '2026-10-11',
          'state': 'confirmed',
          'allocations': const {},
          'advance': '5000',
          'events': [
            {'state': 'pending', 'at': '2026-10-11 01:00:00+00'},
            {'id': 'ok', 'state': 'confirmed'},
          ],
        },
      },
      'activity': activity,
    });

    test('newest first, in plain words, with who did it', () {
      final rows = historyRows(
        with_([
          event('c', 'create', at: '2026-10-01 01:00:00+00'),
          event('bill', 'bill'),
          event('fix', 'correct', reason: 'Wrong total', actor: 'ben'),
          event('back', 'refund', actor: 'di'),
          event('p', 'report', actor: 'ben'),
          event('ok', 'resolve'),
          event('m', 'manual'),
          event('i', 'invite'),
          event('r', 'revoke'),
          event('l', 'leave', actor: 'di', reason: 'Moved out'),
          event('t', 'archive', reason: 'Done'),
        ]),
        a,
        today,
      );
      expect(rows.map((r) => r.title), [
        'You archived or restored the group',
        'Di left',
        'You revoked an invitation',
        'You sent an invitation',
        'You added someone who isn’t registered',
        'You confirmed a payment: Ben → You',
        'Ben logged a payment: Ben → You',
        'Di logged a refund on Dinner',
        'Ben corrected Dinner',
        'You added Dinner',
        'You started the group',
      ]);
      expect(rows.first.reason, 'Done');
    });

    test('rows open what they’re about, with its amount then', () {
      final rows = historyRows(
        with_([
          event('bill', 'bill'),
          event('fix', 'correct'),
          event('back', 'refund'),
          event('p', 'report'),
        ]),
        a,
        today,
      ).reversed.toList();
      expect(rows[0].amount, BigInt.from(30000));
      expect(rows[1].amount, BigInt.from(40000));
      expect(rows[2].amount, BigInt.from(1000));
      expect(rows[2].bill, 'bill');
      expect(rows[3].payment, 'p');
      expect(rows[3].kind, HistoryKind.payment);
    });

    test('people changes name who they were about', () {
      final g = SharedGroup({
        ...crew().data,
        'people': {
          a: person('Ana', user: 'me'),
          b: person(
            'Ben',
            user: 'ben',
            intervals: [
              {'joined': '2026-10-02 01:00:00+00', 'role': 'member'},
              {
                'role': 'owner',
                'changedAt': '2026-10-03 01:00:00+00',
                'actor': 'me',
              },
            ],
          ),
          c: person(
            'Cy',
            kind: 'manual',
            active: false,
            intervals: [
              {'left': '2026-10-04 01:00:00+00', 'actor': 'me'},
            ],
          ),
        },
        'activity': [
          event('j', 'accept', at: '2026-10-02 01:00:00+00', actor: 'ben'),
          event('t', 'transfer', at: '2026-10-03 01:00:00+00'),
          event('x', 'remove', at: '2026-10-04 01:00:00+00'),
        ],
      });
      expect(historyRows(g, a, today).map((r) => r.title), [
        'You removed Cy',
        'You made Ben the owner',
        'Ben joined',
      ]);
    });

    test('a deleted account and an unknown change read plainly', () {
      final rows = historyRows(
        with_([
          event(
            'x',
            'identity_deleted',
            actor: 'gone',
            reason:
                'Shared evidence retained; ownerless administration archived',
          ),
          event('y', 'something-new', actor: 'gone'),
          event('z', 'bill', actor: 'gone'),
        ]),
        a,
        today,
      );
      expect(rows[2].title, 'An account was deleted');
      expect(rows[2].reason, 'Its bills and balance stay.');
      expect(rows[1].title, 'The group changed');
      expect(rows[0].title, 'Someone added a bill');
    });

    test('days are on the Asia/Manila calendar', () {
      final rows = historyRows(
        with_([event('c', 'create', at: '2026-10-31 20:00:00+00')]),
        a,
        today,
      );
      expect(rows.single.date, '2026-11-01');
    });

    test('filters', () {
      final rows = historyRows(
        with_([
          event('c', 'create'),
          event('bill', 'bill'),
          event('p', 'report'),
          event('m', 'manual'),
        ]),
        a,
        today,
      );
      for (final (f, n) in const [
        (HistoryFilter.all, 4),
        (HistoryFilter.bills, 1),
        (HistoryFilter.payments, 1),
        (HistoryFilter.people, 1),
        (HistoryFilter.group, 1),
      ]) {
        expect(rows.where(f.matches).length, n, reason: f.name);
      }
    });
  });

  group('work by tab', () {
    SharedSource source(String op, {String group = 'g'}) => SharedSource(
      today: today,
      groups: [crew()],
      loaded: true,
      connected: true,
      online: true,
      complete: true,
      hidden: false,
      amount: (v) => '₱${phpDecimal(v)}',
      writer: FakeWriter(),
      profileName: 'Ana',
      actor: 'me',
      intents: [
        {
          'id': 'work',
          'group_id': group,
          'state': 'review',
          'reason': 'Owner required',
          'payload': jsonEncode({'op': op, 'values': const {}}),
        },
      ],
    );

    test('each change shows on its own tab, and only that group’s', () {
      for (final (op, scope) in const [
        ('bill', SharedTaskScope.bills),
        ('report', SharedTaskScope.payments),
        ('invite', SharedTaskScope.people),
        ('remove', SharedTaskScope.people),
        ('leave', SharedTaskScope.group),
        ('archive', SharedTaskScope.group),
      ]) {
        for (final tab in SharedTaskScope.values) {
          expect(
            sharedTasks(source(op), crew(), scope: tab).length,
            tab == scope ? 1 : 0,
            reason: '$op on ${tab.name}',
          );
        }
        expect(
          sharedTasks(source(op, group: 'other'), crew(), scope: scope),
          isEmpty,
        );
      }
    });
  });

  group('forms', () {
    late PrototypeSession session;
    setUp(() => session = PrototypeSession());
    tearDown(() => session.dispose());

    Future<FakeWriter> open(
      WidgetTester tester,
      void Function(BuildContext, SharedHub, SharedGroup) show, {
      SharedGroup? g,
      FakeHub? using,
    }) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final group = g ?? crew();
      final hub = using ?? FakeHub(session, FakeWriter(), [group]);
      addTearDown(hub.dispose);
      await tester.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: SalapiyaTheme.build(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => show(context, hub, group),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return hub.writer;
    }

    Future<void> type(WidgetTester tester, String key, String text) async {
      await tester.enterText(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(EditableText),
        ),
        text,
      );
      await tester.pump();
    }

    Future<void> press(WidgetTester tester, String action) async {
      await tester.tap(find.widgetWithText(FilledButton, action).last);
      await tester.pumpAndSettle();
    }

    const lost = 'We couldn’t tell if this reached the group';

    testWidgets('Add a person: one person, even after a lost answer', (
      tester,
    ) async {
      final writer = await open(tester, showAddPerson);
      await press(tester, 'Add person');
      expect(find.text('Enter their name.'), findsOneWidget);
      expect(writer.sent, isEmpty);
      await type(tester, 'person-name', 'Lola Ines');
      writer.failNext = Exception('no answer');
      await press(tester, 'Add person');
      expect(find.text(lost), findsOneWidget);
      await press(tester, 'Add person');
      expect(writer.sent.length, 2);
      expect(writer.sent.first.$2, 'manual');
      expect(writer.sent.first.$3['name'], 'Lola Ines');
      expect(
        writer.sent.first.$3['participant'],
        writer.sent.last.$3['participant'],
      );
      expect(writer.sent.first.$5, writer.sent.last.$5);
      expect(writer.sent.first.$4, 4);
    });

    testWidgets('Invite: the same token after a lost answer, then the code', (
      tester,
    ) async {
      final writer = await open(tester, (c, h, g) => showInvite(c, h, g));
      await type(tester, 'invite-email', 'not an email');
      await press(tester, 'Send invitation');
      expect(find.text('Enter an email like ana@gmail.com.'), findsOneWidget);
      expect(writer.sent, isEmpty);
      await type(tester, 'invite-email', 'ben@example.test');
      writer.failNext = Exception('no answer');
      await press(tester, 'Send invitation');
      await press(tester, 'Send invitation');
      expect(writer.sent.length, 2);
      expect(writer.sent.first.$3, writer.sent.last.$3);
      expect(writer.sent.first.$5, writer.sent.last.$5);
      final values = writer.sent.last.$3;
      expect(values['email'], 'ben@example.test');
      expect(values.containsKey('participant'), isFalse);
      // What's shown is what the server holds the hash of.
      final code = tester
          .widget<SelectableText>(find.byKey(const ValueKey('invite-code')))
          .data!;
      expect(code.startsWith('g.'), isTrue);
      expect(SharedRepository.tokenHash(code.split('.').last), values['hash']);
    });

    testWidgets('Inviting someone to a place names it, and warns', (
      tester,
    ) async {
      final writer = await open(
        tester,
        (x, h, g) => showInvite(x, h, g, person: c),
      );
      expect(find.text('Invite Cy to take this place'), findsOneWidget);
      expect(
        find.textContaining('If the group changes before they accept'),
        findsOneWidget,
      );
      await type(tester, 'invite-email', 'cy@example.test');
      await press(tester, 'Send invitation');
      expect(writer.sent.single.$3['participant'], c);
    });

    testWidgets('Leave says what stays, needs a reason, and sends yours', (
      tester,
    ) async {
      final bills = {
        'x': {
          'creator': a,
          'revisions': [
            {
              'id': 'r',
              'name': 'Rent',
              'date': '2026-10-10',
              'total': '10000',
              'paid': {a: '10000'},
              'shares': {b: '10000'},
            },
          ],
          'refunds': const [],
        },
      };
      final g = crew(bills: bills);
      final writer = await open(
        tester,
        (x, h, g) => showLeave(x, h, g, b),
        g: g,
      );
      expect(find.textContaining('You still owe ₱100.00'), findsOneWidget);
      expect(find.textContaining('doesn’t forgive it'), findsOneWidget);
      await press(tester, 'Leave group');
      expect(find.text('Say why.'), findsOneWidget);
      expect(writer.sent, isEmpty);
      await type(tester, 'change-reason', 'Moved out');
      await press(tester, 'Leave group');
      expect(writer.sent.single.$2, 'leave');
      expect(writer.sent.single.$3, {'reason': 'Moved out', 'participant': b});
    });

    testWidgets('Remove asks who, among those the server accepts', (
      tester,
    ) async {
      final writer = await open(tester, (x, h, g) => showRemove(x, h, g));
      final picker = tester.widget<OptionPicker<String>>(
        find.byKey(const ValueKey('change-person')),
      );
      expect(picker.options.map((o) => o.value), {b, c});
      await type(tester, 'change-reason', 'Asked to go');
      await press(tester, 'Remove from group');
      expect(find.text('Choose someone.'), findsOneWidget);
      expect(writer.sent, isEmpty);
      picker.onChanged!(b);
      await tester.pump();
      await press(tester, 'Remove from group');
      expect(writer.sent.single.$3, {
        'reason': 'Asked to go',
        'participant': b,
      });
    });

    testWidgets('Make someone the owner offers only registered members', (
      tester,
    ) async {
      final writer = await open(tester, (x, h, g) => showTransfer(x, h, g));
      expect(
        tester
            .widget<OptionPicker<String>>(
              find.byKey(const ValueKey('change-person')),
            )
            .options
            .map((o) => o.value),
        {b},
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(writer.sent, isEmpty);
    });

    for (final (archived, action, value) in const [
      (false, 'Archive group', true),
      (true, 'Restore group', false),
    ]) {
      testWidgets('$action sends what it says', (tester) async {
        final writer = await open(
          tester,
          showArchive,
          g: crew(archived: archived),
        );
        expect(find.textContaining('doesn’t clear'), findsOneWidget);
        await type(tester, 'change-reason', 'Because');
        await press(tester, action);
        expect(writer.sent.single.$3, {'reason': 'Because', 'archived': value});
      });
    }

    testWidgets('Revoke sends the invitation, with no reason', (tester) async {
      final writer = await open(
        tester,
        (x, h, g) =>
            showRevoke(x, h, g, const OpenInvitation('i', today, today, null)),
      );
      expect(find.byKey(const ValueKey('change-reason')), findsNothing);
      await press(tester, 'Revoke invitation');
      expect(writer.sent.single.$3, {'invitation': 'i'});
    });

    testWidgets('a stale group stops before anything is sent', (tester) async {
      final writer = FakeWriter();
      final hub = FakeHub(session, writer, [crew(version: 9)]);
      await open(
        tester,
        (x, h, g) => showArchive(x, h, g),
        g: crew(),
        using: hub,
      );
      await type(tester, 'change-reason', 'Because');
      await press(tester, 'Archive group');
      expect(find.text('This group changed'), findsOneWidget);
      expect(writer.sent, isEmpty);
    });

    testWidgets('offline it says so, and sends nothing', (tester) async {
      final writer = FakeWriter()..online = false;
      final hub = FakeHub(session, writer, [crew()]);
      await open(tester, showArchive, using: hub);
      await type(tester, 'change-reason', 'Because');
      await press(tester, 'Archive group');
      expect(find.textContaining('needs a connection'), findsOneWidget);
      expect(writer.sent, isEmpty);
    });

    testWidgets('a refusal reads plainly, and next time is a new command', (
      tester,
    ) async {
      final writer = await open(tester, showArchive);
      await type(tester, 'change-reason', 'Because');
      writer.failNext = const LocalRuleException('Owner required');
      await press(tester, 'Archive group');
      expect(find.text('Only the group’s owner can do this.'), findsOneWidget);
      await press(tester, 'Archive group');
      expect(writer.sent.first.$5, isNot(writer.sent.last.$5));
    });
  });

  group('screens', () {
    Future<void> app(
      WidgetTester tester,
      Widget child, {
      required TargetPlatform platform,
      required double width,
      double text = 1,
      Brightness brightness = Brightness.light,
    }) async {
      const height = 4200.0;
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: SalapiyaTheme.build(brightness, platform: platform),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, height),
              textScaler: TextScaler.linear(text),
            ),
            child: child,
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> tab(
      WidgetTester tester,
      PrototypeSession session,
      String name, {
      TargetPlatform platform = windows,
      double width = 1200,
      double text = 1,
      Brightness brightness = Brightness.light,
      int index = 0,
    }) {
      final hub = SharedHub(session)
        ..selected = session.empty
            ? null
            : demoSharedGroups(civilToday())[index].id;
      addTearDown(hub.dispose);
      return app(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: SharedScreen(session: session, hub: hub, initial: name),
            ),
          ),
        ),
        platform: platform,
        width: width,
        text: text,
        brightness: brightness,
      );
    }

    for (final name in const ['People', 'History', 'Manage Group']) {
      for (final (platform, width) in sizes) {
        for (final text in [1.0, 2.0]) {
          for (final brightness in Brightness.values) {
            testWidgets(
              '$name at ${platform.name} $width, ${text * 100}% text, ${brightness.name}',
              (tester) async {
                final session = PrototypeSession();
                addTearDown(session.dispose);
                await tab(
                  tester,
                  session,
                  name,
                  platform: platform,
                  width: width,
                  text: text,
                  brightness: brightness,
                );
                expect(tester.takeException(), isNull);
                await tester.pumpWidget(const SizedBox.shrink());
              },
            );
          }
        }
      }

      for (final scenario in [
        OverviewScenario.empty,
        OverviewScenario.incomplete,
        OverviewScenario.pending,
        OverviewScenario.review,
        OverviewScenario.waiting,
      ]) {
        for (final (platform, width) in const [
          (android, 320.0),
          (windows, 1200.0),
        ]) {
          testWidgets('$name, ${scenario.name} at ${platform.name}', (
            tester,
          ) async {
            final session = PrototypeSession()..select(scenario);
            addTearDown(session.dispose);
            await tab(tester, session, name, platform: platform, width: width);
            expect(tester.takeException(), isNull);
            if (scenario == OverviewScenario.incomplete) {
              expect(find.textContaining('₱'), findsNothing);
            }
            await tester.pumpWidget(const SizedBox.shrink());
          });
        }
      }

      for (final (platform, width) in sizes) {
        testWidgets('$name, hidden amounts at ${platform.name} $width', (
          tester,
        ) async {
          final session = PrototypeSession()..togglePrivacy();
          addTearDown(session.dispose);
          await tab(tester, session, name, platform: platform, width: width);
          expect(tester.takeException(), isNull);
          expect(find.textContaining('₱'), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }

      for (var index = 0; index < 5; index++) {
        testWidgets('$name, sample group $index', (tester) async {
          final session = PrototypeSession();
          addTearDown(session.dispose);
          await tab(tester, session, name, index: index);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }

    testWidgets(
      'Manage Group: an owner sees theirs, and why they can’t leave',
      (tester) async {
        final session = PrototypeSession();
        addTearDown(session.dispose);
        await tab(tester, session, 'Manage Group');
        for (final key in const [
          'lifecycle-transfer',
          'lifecycle-remove',
          'lifecycle-archive',
        ]) {
          expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
        }
        expect(find.byKey(const ValueKey('lifecycle-leave')), findsNothing);
        expect(find.byKey(const ValueKey('lifecycle-restore')), findsNothing);
        expect(
          find.textContaining('As the owner, you can’t leave.'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('Manage Group: a member can only leave', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session, 'Manage Group', index: 1);
      expect(find.byKey(const ValueKey('lifecycle-leave')), findsOneWidget);
      for (final key in const [
        'lifecycle-transfer',
        'lifecycle-remove',
        'lifecycle-archive',
      ]) {
        expect(find.byKey(ValueKey(key)), findsNothing, reason: key);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Manage Group: an archived group offers Restore', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session, 'Manage Group', index: 2);
      expect(find.byKey(const ValueKey('lifecycle-restore')), findsOneWidget);
      expect(find.byKey(const ValueKey('lifecycle-archive')), findsNothing);
      expect(find.byKey(const ValueKey('lifecycle-remove')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Manage Group: a group you left offers nothing', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session, 'Manage Group', index: 3);
      expect(find.text('You’ve left this group'), findsOneWidget);
      expect(find.byKey(const ValueKey('lifecycle-leave')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('People: what the owner can do shows only to the owner', (
      tester,
    ) async {
      final owner = PrototypeSession();
      addTearDown(owner.dispose);
      await tab(tester, owner, 'People');
      expect(find.byKey(const ValueKey('people-add')), findsOneWidget);
      expect(find.byKey(const ValueKey('people-invitations')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      for (final index in const [1, 2, 3]) {
        final session = PrototypeSession();
        addTearDown(session.dispose);
        await tab(tester, session, 'People', index: index);
        expect(find.byKey(const ValueKey('people-add')), findsNothing);
        expect(find.byKey(const ValueKey('people-invitations')), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('People: plain words, and no ids or JSON', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session, 'People');
      expect(find.text('Not registered'), findsWidgets);
      expect(find.text('Left'), findsWidgets);
      expect(find.textContaining('intervals'), findsNothing);
      expect(find.textContaining('joined":'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a person’s page offers only what applies', (tester) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      final g = demoSharedGroups(civilToday()).first;
      final lola = sharedMembers(
        g,
        g.participant(demoActor),
      ).firstWhere((m) => m.role == MemberRole.notRegistered);
      final hub = SharedHub(session)..selected = g.id;
      addTearDown(hub.dispose);
      await app(
        tester,
        SharedPersonPage(hub: hub, group: g.id, person: lola.person),
        platform: windows,
        width: 1200,
      );
      await tester.tap(find.byKey(const ValueKey('person-actions')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('person-claim')), findsOneWidget);
      expect(find.byKey(const ValueKey('person-remove')), findsOneWidget);
      expect(find.byKey(const ValueKey('person-make-owner')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('History: no raw operation names or timestamps', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session, 'History');
      expect(find.textContaining('identity_deleted'), findsNothing);
      expect(find.textContaining('+08'), findsNothing);
      expect(find.text('Previous page'), findsNothing);
      expect(find.textContaining('logged a payment'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('History: copying is off while amounts are hidden', (
      tester,
    ) async {
      final session = PrototypeSession()..togglePrivacy();
      addTearDown(session.dispose);
      await tab(tester, session, 'History');
      await tester.tap(find.byKey(const ValueKey('history-menu')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MenuItemButton>(find.byKey(const ValueKey('history-copy')))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('History: a group you left says why it’s empty', (
      tester,
    ) async {
      final session = PrototypeSession();
      addTearDown(session.dispose);
      await tab(tester, session, 'History', index: 3);
      expect(find.text('No history here'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final (platform, width) in const [
      (android, 320.0),
      (windows, 1200.0),
    ]) {
      testWidgets('History as a page at ${platform.name}', (tester) async {
        final session = PrototypeSession();
        addTearDown(session.dispose);
        final hub = SharedHub(session)..selected = demoHouseholdId;
        addTearDown(hub.dispose);
        await app(
          tester,
          SharedHistoryPage(hub: hub, group: demoHouseholdId),
          platform: platform,
          width: width,
          text: 2,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });
}
