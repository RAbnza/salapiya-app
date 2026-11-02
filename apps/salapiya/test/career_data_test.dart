import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/life/life_controller.dart';
import 'package:salapiya/life/life_data.dart';
import 'package:salapiya/life/life_demo.dart';
import 'package:salapiya/life/life_domain.dart';
import 'package:salapiya/life/native_notifications.dart';
import 'package:salapiya/local/finance_domain.dart';

const today = '2026-11-04'; // A Wednesday.
const zone = 'Asia/Manila';
const owner = '00000000-0000-4000-8000-00000000d000';
String id(int n) =>
    '00000000-0000-4000-8000-${n.toRadixString(16).padLeft(12, '0')}';

var _next = 1;

ApplicationRecord app(
  String company, {
  String stage = 'Applied',
  String outcome = '',
  String date = '2026-10-01',
  String moved = '2026-10-02',
  String followUp = '',
  String archived = 'false',
  Map<String, String> more = const {},
}) =>
    LifeRecord.read(id(_next++), owner, 1, LifeType.application, {
          'title': 'Role',
          'company': company,
          'status': outcome.isEmpty ? stage : outcome,
          'pipelineStage': stage,
          'outcome': outcome,
          'date': stage == 'Saved' ? '' : date,
          'stageDate': moved,
          'followUp': followUp,
          'archived': archived,
          ...more,
        })
        as ApplicationRecord;

CareerEventRecord step(
  ApplicationRecord on,
  String kind,
  String date, {
  String time = '',
  String timezone = zone,
  String status = 'Scheduled',
}) =>
    LifeRecord.read(id(_next++), owner, 1, LifeType.careerEvent, {
          'title': kind,
          'eventKind': kind,
          'application': on.id,
          'date': date,
          'time': time,
          'timezone': timezone,
          'status': status,
        })
        as CareerEventRecord;

Map<String, LifeRecord> byId(List<LifeRecord> records) => {
  for (final r in records) r.id: r,
};

List<ApplicationRow> rows(List<LifeRecord> records) =>
    applicationRows(byId(records), today, zone);

CareerCounts counts(List<LifeRecord> records) {
  final m = byId(records);
  return CareerCounts(
    applicationRows(m, today, zone),
    nextSteps(careerRows(m, today, zone)),
  );
}

void main() {
  group('stages', () {
    test('an empty profile counts nothing', () {
      final c = counts(const []);
      expect(c.active, isEmpty);
      expect(c.next, isEmpty);
      expect(c.upcoming, isNull);
      expect(c.oldest, isNull);
    });

    test('every stage counts where it is', () {
      for (final stage in careerPipelineStages.where((s) => s != 'Accepted')) {
        final c = counts([app('x', stage: stage)]);
        expect(c.stage(stage), 1, reason: stage);
        expect(c.active, hasLength(1), reason: stage);
        expect(c.closed, isEmpty, reason: stage);
      }
    });

    test('every outcome closes it, and keeps its last stage', () {
      for (final outcome in careerOutcomes) {
        final stage = outcome == 'Accepted' ? 'Accepted' : 'Interview';
        final a = app('x', stage: stage, outcome: outcome);
        final c = counts([a]);
        expect(c.active, isEmpty, reason: outcome);
        expect(c.outcome(outcome), 1, reason: outcome);
        expect(rows([a]).single.stage, stage, reason: outcome);
        expect(rows([a]).single.closed, isTrue, reason: outcome);
      }
    });

    test('a stored outcome reads plainly and stays as it is', () {
      final r = rows([
        app('x', stage: 'Offer', outcome: 'Employer-cancelled opening'),
      ]).single;
      expect(r.standing, 'Opening cancelled');
      expect(r.outcome, 'Employer-cancelled opening');
    });

    test('Interviewing counts the three stages it means', () {
      final c = counts([
        app('a', stage: 'Interview'),
        app('b', stage: 'Technical assessment'),
        app('c', stage: 'Final interview'),
        app('d', stage: 'Screening'),
        app('e', stage: 'Offer'),
      ]);
      expect(c.interviewing, 3);
    });

    test('an older closed record reads Not recorded', () {
      final r =
          LifeRecord.read(id(9000), owner, 1, LifeType.application, {
                'title': 'Role',
                'company': 'Old',
                'status': 'Rejected',
                'date': '2026-01-01',
                'stageDate': '2026-01-02',
              })
              as ApplicationRecord;
      expect(r.stage, 'Unspecified in preset v1');
      final row = rows([r]).single;
      expect(row.stage, isNull);
      expect(row.standing, 'Rejected');
    });

    test('an archived application is in no count', () {
      final c = counts([app('x', archived: 'true')]);
      expect(c.active, isEmpty);
      expect(c.closed, isEmpty);
      expect(c.stage('Applied'), 0);
    });

  });

  group('steps', () {
    test('a cancelled step isn’t a finished one', () {
      final a = app('x');
      final s = step(a, 'Interview', '2026-11-10', time: '10:00', status: 'Cancelled');
      expect(StepRow(s, today, zone).state, CareerStepState.cancelled);
      expect(StepRow(s, today, zone).open, isFalse);
    });

    test('a date passing makes an interview past and a follow-up overdue', () {
      final a = app('x');
      for (final (kind, time, state) in [
        ('Interview', '10:00', CareerStepState.past),
        ('Assessment', '10:00', CareerStepState.past),
        ('Follow-up', '', CareerStepState.overdue),
      ]) {
        final s = step(a, kind, '2026-11-03', time: time);
        expect(StepRow(s, today, zone).state, state, reason: kind);
      }
    });

    test('today is neither', () {
      final a = app('x');
      expect(
        StepRow(step(a, 'Follow-up', today), today, zone).state,
        CareerStepState.scheduled,
      );
    });

    test('what happened is logged, and can’t be reopened', () {
      final a = app('x');
      for (final kind in careerObservations) {
        final s = step(a, kind, '2026-10-05', status: 'Completed');
        final r = StepRow(s, today, zone);
        expect(r.state, CareerStepState.logged, reason: kind);
        expect(r.open, isFalse, reason: kind);
      }
    });

    test('what’s ahead comes first, nearest first, then newest first', () {
      final a = app('x');
      final r = rows([
        a,
        step(a, 'Interview', '2026-10-01', time: '10:00', status: 'Completed'),
        step(a, 'Interview', '2026-10-20', time: '10:00', status: 'Completed'),
        step(a, 'Interview', '2026-12-01', time: '10:00'),
        step(a, 'Interview', '2026-11-10', time: '10:00'),
      ]).single;
      expect(r.steps.map((s) => s.date), [
        '2026-11-10',
        '2026-12-01',
        '2026-10-20',
        '2026-10-01',
      ]);
    });

    test('a timed step sits on its date where the user is', () {
      final a = app('x');
      // 8 AM on the 5th in Honolulu is 2 AM on the 6th in Manila.
      final s = step(
        a,
        'Interview',
        '2026-11-05',
        time: '08:00',
        timezone: 'Pacific/Honolulu',
      );
      final r = StepRow(s, today, zone);
      expect(r.date, '2026-11-06');
      expect(r.time, '02:00');
    });

    test('an all-day step keeps its date in any timezone', () {
      final a = app('x');
      final s = step(a, 'Follow-up', '2026-11-05');
      expect(StepRow(s, today, 'Pacific/Honolulu').date, '2026-11-05');
    });

    test('daylight saving: a time that repeats keeps the one chosen', () {
      final a = app('x');
      // Sydney's clocks went back on 5 Apr 2026: 2:30 AM happens twice.
      final early = LifeRecord.read(id(9001), owner, 1, LifeType.careerEvent, {
        'title': 'Interview',
        'eventKind': 'Interview',
        'application': a.id,
        'date': '2026-04-05',
        'time': '02:30',
        'timezone': 'Australia/Sydney',
        'fold': 'Earlier',
      }) as CareerEventRecord;
      final late = LifeRecord.read(id(9002), owner, 1, LifeType.careerEvent, {
        ...early.fields,
        'fold': 'Later',
        'utc': '',
      }) as CareerEventRecord;
      expect(early.utc!.isBefore(late.utc!), isTrue);
    });

    test('daylight saving: a time that doesn’t exist is refused', () {
      final a = app('x');
      expect(
        () => LifeRecord.read(id(9003), owner, 1, LifeType.careerEvent, {
          'title': 'Interview',
          'eventKind': 'Interview',
          'application': a.id,
          'date': '2026-10-04',
          'time': '02:30',
          'timezone': 'Australia/Sydney',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('next steps', () {
    test('overdue follow-ups come first; interviews gone by aren’t next', () {
      final a = app('x', followUp: '2026-11-01');
      final c = counts([
        a,
        step(a, 'Interview', '2026-11-10', time: '10:00'),
        step(a, 'Interview', '2026-11-02', time: '10:00'),
        step(a, 'Follow-up', '2026-11-03'),
      ]);
      expect(c.next.map((r) => r.date), [
        '2026-11-01',
        '2026-11-03',
        '2026-11-10',
      ]);
      expect(c.overdue, hasLength(2));
      expect(c.oldest, 3);
      expect(c.upcoming?.date, '2026-11-10');
    });

    test('a follow-up step is late on the Calendar’s rows too', () {
      final a = app('x');
      final r = careerRows(
        byId([a, step(a, 'Follow-up', '2026-11-03', time: '09:00')]),
        today,
        zone,
      ).single;
      expect(r.late, isTrue);
      expect(r.event, isFalse);
    });

    test('an interview on the Calendar’s rows still only goes by', () {
      final a = app('x');
      final r = careerRows(
        byId([a, step(a, 'Interview', '2026-11-03', time: '09:00')]),
        today,
        zone,
      ).single;
      expect(r.late, isFalse);
      expect(r.past, isTrue);
    });

    test('closed and archived applications have no next step', () {
      final closed = app('x', stage: 'Interview', outcome: 'Rejected');
      final gone = app('y', archived: 'true', followUp: '2026-12-01');
      final c = counts([
        closed,
        gone,
        step(closed, 'Interview', '2026-12-01', time: '10:00'),
        step(gone, 'Interview', '2026-12-01', time: '10:00'),
      ]);
      expect(c.next, isEmpty);
      expect(rows([closed]).single.next, isNull);
    });

    test('a step that’s done or cancelled isn’t next', () {
      final a = app('x');
      final c = counts([
        a,
        step(a, 'Follow-up', '2026-12-01', status: 'Completed'),
        step(a, 'Follow-up', '2026-12-02', status: 'Cancelled'),
      ]);
      expect(c.next, isEmpty);
    });

    test('year edges count calendar days', () {
      final a = app('x', followUp: '2026-12-31');
      final r = careerRows(byId([a]), '2027-01-01', zone).single;
      expect(r.days, -1);
      expect(r.late, isTrue);
    });
  });

  group('order and filters', () {
    final soon = app('Soon', followUp: '2026-11-10');
    final later = app('Later', followUp: '2026-12-10');
    final moved = app('Moved', moved: '2026-10-20');
    final older = app('Older', moved: '2026-10-05');
    final done = app('Done', stage: 'Interview', outcome: 'Withdrawn');
    final gone = app('Gone', archived: 'true');
    final all = rows([older, moved, later, soon, done, gone]);

    test('open ones first, by what’s next, then the newest move', () {
      expect(all.take(4).map((r) => r.company), [
        'Soon',
        'Later',
        'Moved',
        'Older',
      ]);
    });

    test('each filter leaves the right rows', () {
      expect(
        filterApplications(all, ApplicationFilter.active),
        hasLength(4),
      );
      expect(
        filterApplications(all, ApplicationFilter.closed).single.company,
        'Done',
      );
      expect(
        filterApplications(all, ApplicationFilter.archived).single.company,
        'Gone',
      );
      expect(filterApplications(all, ApplicationFilter.all), hasLength(6));
    });

    test('search reads company and role, and nothing private', () {
      final a = app('Acme', more: {'notes': 'secret', 'contact': 'Tala'});
      final r = rows([a]);
      expect(filterApplications(r, ApplicationFilter.all, words: 'ACME'), hasLength(1));
      expect(filterApplications(r, ApplicationFilter.all, words: 'role'), hasLength(1));
      expect(filterApplications(r, ApplicationFilter.all, words: 'secret'), isEmpty);
      expect(filterApplications(r, ApplicationFilter.all, words: 'tala'), isEmpty);
    });

    test('a stage narrows it', () {
      final r = rows([app('a', stage: 'Interview'), app('b', stage: 'Offer')]);
      expect(
        filterApplications(r, ApplicationFilter.all, stage: 'Offer').single.company,
        'b',
      );
    });
  });

  group('salary', () {
    Map<String, String> v(String low, String high, [String c = 'PHP', String p = 'month']) => {
      'salaryMin': low,
      'salaryMax': high,
      'currency': c,
      'salaryPeriod': p,
    };

    test('none reads as none', () {
      expect(salaryLine(v('', ''), hidden: false), isNull);
      expect(salaryLine(v('', ''), hidden: true), isNull);
    });

    test('it reads as a range, in its own currency', () {
      expect(
        salaryLine(v('60000', '80000'), hidden: false),
        '₱60,000.00 to ₱80,000.00 a month',
      );
      expect(
        salaryLine(v('3000.5', '3500', 'USD', 'year'), hidden: false),
        'USD 3,000.50 to USD 3,500.00 a year',
      );
      expect(salaryLine(v('500', '', 'PHP', 'hour'), hidden: false), 'From ₱500.00 an hour');
      expect(salaryLine(v('', '90000'), hidden: false), 'Up to ₱90,000.00 a month');
      expect(salaryLine(v('5', '5'), hidden: false), '₱5.00 a month');
    });

    test('Hide amounts covers it', () {
      expect(salaryLine(v('60000', '80000'), hidden: true), 'Amount hidden');
    });

    test('big figures keep every digit', () {
      expect(
        salaryLine(v('999999999999.99', ''), hidden: false),
        'From ₱999,999,999,999.99 a month',
      );
    });
  });

  group('history', () {
    LifeCommand c(int version, Map<String, String> fields) => LifeCommand(
      id: id(9200 + version),
      owner: owner,
      recordId: id(9300),
      type: LifeType.application,
      expectedVersion: version,
      fields: {
        'title': 'Role',
        'company': 'x',
        'status': 'Applied',
        'date': '2026-10-01',
        'stageDate': '2026-10-01',
        ...fields,
      },
      reason: 'r',
      recordedAt: DateTime.utc(2026),
    );

    test('it says what moved, including salary and stage', () {
      final changes = lifeChanges([
        ('a', c(0, {})),
        ('b', c(1, {'status': 'Screening', 'salaryMin': '5'})),
      ]);
      expect(changes.first.fields, contains(('status', 'Applied', 'Screening')));
      expect(changes.first.fields, contains(('salaryMin', '', '5')));
    });
  });

  group('changes to check', () {
    test('a step on a closed application can only be kept', () {
      final closed = app('x', stage: 'Interview', outcome: 'Rejected');
      final s = step(closed, 'Interview', '2026-12-01', time: '10:00');
      final edit = LifeCommand(
        id: id(9400),
        owner: owner,
        recordId: s.id,
        type: LifeType.careerEvent,
        expectedVersion: 1,
        fields: {...s.fields, 'notes': 'x'},
        reason: 'r',
        recordedAt: DateTime.utc(2026),
      );
      final row = lifeReviewRows(
        [
          {
            'id': edit.id,
            'payload': edit.payload,
            'state': 'review',
            'reason': 'x',
            'resolved_at': null,
          },
        ],
        byId([closed, s]),
      ).single;
      expect(row.usable, isFalse);
    });

    test('an edit that still fits can be used', () {
      final a = app('x');
      final s = step(a, 'Interview', '2026-12-01', time: '10:00');
      final edit = LifeCommand(
        id: id(9401),
        owner: owner,
        recordId: s.id,
        type: LifeType.careerEvent,
        expectedVersion: 1,
        fields: {...s.fields, 'notes': 'x'},
        reason: 'r',
        recordedAt: DateTime.utc(2026),
      );
      final row = lifeReviewRows(
        [
          {
            'id': edit.id,
            'payload': edit.payload,
            'state': 'review',
            'reason': 'x',
            'resolved_at': null,
          },
        ],
        byId([a, s]),
      ).single;
      expect(row.usable, isTrue);
    });
  });

  group('duplicates', () {
    test('company and role match whatever the case and spacing', () {
      final records = byId([app('Acme')]);
      expect(
        lifeIsDuplicate(records, {'company': ' acme ', 'position': 'ROLE '}),
        isTrue,
      );
      expect(
        lifeIsDuplicate(records, {'company': 'Acme', 'position': 'Other'}),
        isFalse,
      );
    });

    test('the rule waits for the user to say it’s separate', () {
      final records = byId([app('Acme')]);
      final v = {'company': 'Acme', 'position': 'Role'};
      expect(
        () => lifeCheckDuplicate(records, v),
        throwsA(isA<FormatException>()),
      );
      lifeCheckDuplicate(records, {...v, 'duplicateConsent': 'true'});
    });
  });

  group('notifications', () {
    test('they carry no title, company, contact, salary or note', () {
      final a = app(
        'Acme',
        more: {'contact': 'Tala', 'salaryMin': '60000', 'notes': 'Private'},
      );
      final item = careerRows(
        byId([a, step(a, 'Interview', '2026-12-01', time: '10:00')]),
        today,
        zone,
      ).single.item!;
      final words = [
        reminderTitle,
        reminderBody(),
        reminderBody(showDate: true, date: item.date),
      ].join(' ');
      for (final secret in const ['Acme', 'Interview', 'Tala', '60000', 'Private', 'Role']) {
        expect(words, isNot(contains(secret)), reason: secret);
      }
    });
  });

  group('demo sample', () {
    test('it replays on week, month and year edges', () {
      for (final day in [
        '2026-01-01', '2026-02-28', '2026-03-01', '2026-11-01',
        '2026-11-30', '2026-12-31', '2027-01-01', '2028-02-29',
      ]) {
        final life = demoLife(day);
        final r = applicationRows(life.records, day, zone);
        final c = CareerCounts(r, nextSteps(careerRows(life.records, day, zone)));
        for (final stage in careerPipelineStages.where((s) => s != 'Accepted')) {
          expect(c.stage(stage), greaterThan(0), reason: '$day $stage');
        }
        for (final outcome in careerOutcomes) {
          expect(c.outcome(outcome), greaterThan(0), reason: '$day $outcome');
        }
        expect(c.overdue, isNotEmpty, reason: day);
        expect(r.where((a) => a.archived), isNotEmpty, reason: day);
        expect(
          c.next.where((n) => n.recordedZone != null),
          isNotEmpty,
          reason: day,
        );
      }
    });

    test('every command replays through the rules', () {
      final life = demoLife(civilToday());
      final replayed = <String, LifeRecord>{};
      for (final (_, c) in life.log) {
        replayed[c.recordId] = applyLifeCommand(replayed, c);
      }
      expect(replayed.length, life.records.length);
    });
  });
}
