import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/app/overview_data.dart' show monthStart;
import 'package:salapiya/life/life_controller.dart';
import 'package:salapiya/life/life_data.dart';
import 'package:salapiya/life/life_demo.dart';
import 'package:salapiya/life/life_domain.dart';
import 'package:salapiya/local/finance_domain.dart';

const today = '2026-11-04'; // A Wednesday.
const owner = '00000000-0000-4000-8000-00000000d000';
String id(int n) =>
    '00000000-0000-4000-8000-${n.toRadixString(16).padLeft(12, '0')}';

var _next = 1;

LifeRecord item(
  LifeType type, {
  String title = 'Item',
  String due = '',
  int total = 1,
  int progress = 0,
  String status = 'In progress',
  String completed = '',
  String archived = 'false',
  String rating = '',
  String detail = '',
}) => LifeRecord.read(id(_next++), owner, 1, type, {
  'title': title,
  'detail': detail,
  'due': due,
  'total': '$total',
  'progress': '$progress',
  'status': status,
  'completed': completed,
  'archived': archived,
  if (type == LifeType.book) 'rating': rating,
});

Map<String, LifeRecord> byId(List<LifeRecord> records) => {
  for (final r in records) r.id: r,
};

List<ProgressRow> rows(List<LifeRecord> records, [LifeType? type]) =>
    progressRows(byId(records), type ?? LifeType.book, today);

void main() {
  group('rows', () {
    test('an empty profile has no rows and no next date', () {
      final counts = ProgressCounts(rows(const []));
      expect(counts.inProgress, isEmpty);
      expect(counts.next, isEmpty);
      expect(counts.nextDated, isNull);
      expect(counts.finished, 0);
    });

    test('each type lists only its own', () {
      final records = [
        item(LifeType.book, title: 'Book'),
        item(LifeType.learning, title: 'Course'),
      ];
      expect(rows(records, LifeType.book).single.title, 'Book');
      expect(rows(records, LifeType.learning).single.title, 'Course');
    });

    test('a total of one is the rules’ way of saying there isn’t one', () {
      final one = rows([item(LifeType.book, total: 1)]).single;
      final two = rows([item(LifeType.book, total: 2, progress: 1)]).single;
      expect(one.hasTotal, isFalse);
      expect(two.hasTotal, isTrue);
      expect(two.left, 1);
    });

    test('the states don’t overlap', () {
      for (final (status, archived, expected) in [
        ('In progress', 'false', 'inProgress'),
        ('Not started', 'false', 'notStarted'),
        ('On hold', 'false', 'onHold'),
        ('Completed', 'false', 'finished'),
        ('In progress', 'true', 'archived'),
        ('Completed', 'true', 'archived'),
      ]) {
        final r = rows([
          item(LifeType.book, status: status, archived: archived),
        ]).single;
        final found = {
          if (r.inProgress) 'inProgress',
          if (r.notStarted) 'notStarted',
          if (r.onHold) 'onHold',
          if (!r.archived && r.finished) 'finished',
          if (r.archived) 'archived',
        };
        expect(found, {expected}, reason: '$status, $archived');
      }
    });

    test('a date finished only counts while it’s finished', () {
      final reopened = rows([item(LifeType.book, completed: '2026-10-01')])
          .single;
      final done = rows([
        item(LifeType.book, status: 'Completed', completed: '2026-10-01'),
      ]).single;
      expect(reopened.finishedOn, isNull);
      expect(done.finishedOn, '2026-10-01');
    });

    test('overdue, today and later against today', () {
      final r = rows([
        item(LifeType.book, due: '2026-11-03', title: 'Late'),
        item(LifeType.book, due: today, title: 'Today'),
        item(LifeType.book, due: '2026-11-05', title: 'Later'),
        item(LifeType.book, title: 'None'),
      ]);
      expect(r.map((x) => x.title), ['Late', 'Today', 'Later', 'None']);
      expect(r[0].late, isTrue);
      expect(r[0].days, -1);
      expect(r[1].late, isFalse);
      expect(r[1].dueToday, isTrue);
      expect(r[2].late, isFalse);
      expect(r[3].days, isNull);
      expect(r[3].late, isFalse);
    });

    test('nothing finished, archived or undated is overdue', () {
      final counts = ProgressCounts(
        rows([
          item(LifeType.book, due: '2026-01-01', status: 'Completed'),
          item(LifeType.book, due: '2026-01-01', archived: 'true'),
          item(LifeType.book),
        ]),
      );
      expect(counts.overdue, 0);
    });

    test('month and year edges count calendar days', () {
      for (final (from, due, days) in [
        ('2026-12-31', '2027-01-01', 1),
        ('2027-01-01', '2026-12-31', -1),
        ('2026-10-31', '2026-11-01', 1),
        ('2028-02-28', '2028-02-29', 1),
        ('2028-02-29', '2028-03-01', 1),
      ]) {
        final r = progressRows(
          byId([item(LifeType.book, due: due)]),
          LifeType.book,
          from,
        ).single;
        expect(r.days, days, reason: '$from to $due');
      }
    });

    test('rows with no date keep the order they were added', () {
      final r = rows([
        item(LifeType.book, title: 'First'),
        item(LifeType.book, title: 'Second'),
        item(LifeType.book, title: 'Third'),
      ]);
      expect(r.map((x) => x.title), ['First', 'Second', 'Third']);
    });
  });

  group('filters', () {
    final all = rows([
      item(LifeType.book, title: 'Open', detail: 'Solnit'),
      item(LifeType.book, title: 'Held', status: 'On hold'),
      item(
        LifeType.book,
        title: 'Older',
        status: 'Completed',
        completed: '2025-01-01',
      ),
      item(
        LifeType.book,
        title: 'Newer',
        status: 'Completed',
        completed: '2026-01-01',
      ),
      item(LifeType.book, title: 'Undated', status: 'Completed'),
      item(LifeType.book, title: 'Gone', archived: 'true'),
    ]);

    test('each filter leaves the right rows', () {
      expect(filterProgress(all, ProgressFilter.active).map((r) => r.title), [
        'Open',
        'Held',
      ]);
      expect(filterProgress(all, ProgressFilter.archived).single.title, 'Gone');
      expect(filterProgress(all, ProgressFilter.all), hasLength(6));
    });

    test('finished reads newest first, with undated ones last', () {
      expect(filterProgress(all, ProgressFilter.finished).map((r) => r.title), [
        'Newer',
        'Older',
        'Undated',
      ]);
    });

    test('search looks through the title and author', () {
      expect(
        filterProgress(all, ProgressFilter.all, ' solnit ').single.title,
        'Open',
      );
      expect(filterProgress(all, ProgressFilter.all, 'HELD'), hasLength(1));
      expect(filterProgress(all, ProgressFilter.all, 'nothing'), isEmpty);
    });
  });

  group('counts', () {
    test(
      'what’s next has dates, then what hasn’t started, and nothing held',
      () {
        final counts = ProgressCounts(
          rows([
            item(LifeType.learning, title: 'Dated', due: '2026-12-01'),
            item(LifeType.learning, title: 'Open, no date'),
            item(LifeType.learning, title: 'Waiting', status: 'Not started'),
            item(
              LifeType.learning,
              title: 'Held',
              status: 'On hold',
              due: '2026-11-05',
            ),
            item(LifeType.learning, title: 'Done', status: 'Completed'),
          ], LifeType.learning),
        );
        expect(counts.next.map((r) => r.title), ['Dated', 'Waiting']);
        expect(counts.nextDated?.title, 'Dated');
      },
    );

    test('overdue comes first as the next date', () {
      final counts = ProgressCounts(
        rows([
          item(LifeType.learning, title: 'Later', due: '2026-12-01'),
          item(LifeType.learning, title: 'Late', due: '2026-10-01'),
        ], LifeType.learning),
      );
      expect(counts.nextDated?.title, 'Late');
    });

    test('finished in a year reads recorded dates only', () {
      final counts = ProgressCounts(
        rows([
          item(LifeType.book, status: 'Completed', completed: '2026-02-01'),
          item(LifeType.book, status: 'Completed', completed: '2026-12-31'),
          item(LifeType.book, status: 'Completed', completed: '2025-12-31'),
          item(LifeType.book, status: 'Completed'),
          item(
            LifeType.book,
            status: 'Completed',
            completed: '2026-03-01',
            archived: 'true',
          ),
        ]),
      );
      expect(counts.finished, 4);
      expect(counts.finishedIn('2026'), 2);
      expect(counts.finishedIn('2027'), 0);
    });
  });

  group('Log progress', () {
    final book = item(LifeType.book, total: 10, progress: 2) as ProgressRecord;

    LifeCommand command(Map<String, String> v) => lifeProgressCommand(
      owner,
      book,
      {'__command': id(9000), '__version': '1', ...v},
    );

    test('sends the same fields as the old action', () {
      final c = command({'progress': '5', 'note': ' Chapter 2 '});
      expect(c.id, id(9000));
      expect(c.fields['progress'], '5');
      expect(c.fields['status'], 'In progress');
      expect(c.fields['completed'], '');
      expect(c.reason, 'Chapter 2');
      expect(c.expectedVersion, 1);
    });

    test('with no note it says so, as before', () {
      expect(command({'progress': '5'}).reason, 'Progress updated');
    });

    test('the total finishes it, with a date only if one was given', () {
      expect(command({'progress': '10'}).fields['status'], 'Completed');
      expect(command({'progress': '10'}).fields['completed'], '');
      expect(
        command({'progress': '10', 'completed': '2026-11-01'})
            .fields['completed'],
        '2026-11-01',
      );
    });

    test('a date is ignored short of the total', () {
      expect(
        command({'progress': '9', 'completed': '2026-11-01'})
            .fields['completed'],
        '',
      );
    });

    test('the rules’ limits hold', () {
      for (final value in ['-1', '11', '', 'x']) {
        expect(
          () => command({'progress': value}),
          throwsA(isA<FormatException>()),
          reason: value,
        );
      }
    });

    test('an archived item can’t take progress', () {
      final gone =
          item(LifeType.book, total: 10, archived: 'true') as ProgressRecord;
      expect(
        () => lifeProgressCommand(owner, gone, {'progress': '1'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('a date before the start lands on the rule', () {
      final started = LifeRecord.read(id(9100), owner, 1, LifeType.book, {
        'title': 'x',
        'total': '10',
        'started': '2026-10-01',
      }) as ProgressRecord;
      expect(
        () => lifeProgressCommand(owner, started, {
          'progress': '10',
          'completed': '2026-09-01',
          '__version': '1',
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('date finished can’t be'),
          ),
        ),
      );
    });
  });

  group('history', () {
    test('it says how far a version moved', () {
      LifeCommand c(int version, String progress) => LifeCommand(
        id: id(9200 + version),
        owner: owner,
        recordId: id(9300),
        type: LifeType.book,
        expectedVersion: version,
        fields: {'title': 'x', 'total': '10', 'progress': progress},
        reason: 'r',
        recordedAt: DateTime.utc(2026),
      );
      final changes = lifeChanges([('a', c(0, '1')), ('b', c(1, '3'))]);
      expect(changes.first.fields, contains(('progress', '1', '3')));
    });
  });

  group('demo sample', () {
    test('it replays on week, month and year edges', () {
      for (final day in [
        '2026-01-01',
        '2026-02-28',
        '2026-03-01',
        '2026-11-01',
        '2026-11-30',
        '2026-12-31',
        '2027-01-01',
        '2028-02-29',
      ]) {
        final life = demoLife(day);
        for (final type in [LifeType.learning, LifeType.book]) {
          final r = progressRows(life.records, type, day);
          final counts = ProgressCounts(r);
          expect(counts.inProgress, isNotEmpty, reason: '$day $type');
          expect(counts.notStarted, isNotEmpty, reason: '$day $type');
          expect(counts.onHold, greaterThan(0), reason: '$day $type');
          expect(counts.finished, greaterThan(0), reason: '$day $type');
          expect(r.where((x) => x.archived), isNotEmpty, reason: '$day $type');
          expect(r.where((x) => !x.hasTotal), isNotEmpty, reason: '$day $type');
        }
        expect(
          progressRows(
            life.records,
            LifeType.learning,
            day,
          ).where((r) => r.late),
          isNotEmpty,
          reason: day,
        );
      }
    });

    test('its due dates reach the Calendar', () {
      final life = demoLife(today);
      final items = lifeAgendaItems(
        life.records,
        '1900-01-01',
        '2100-01-01',
      ).map((i) => i.kind);
      expect(items, containsAll(['Learning', 'Books']));
      expect(monthStart(today), '2026-11-01');
    });

    test('a finished book’s date and rating read back', () {
      final r = progressRows(
        demoLife(civilToday()).records,
        LifeType.book,
        civilToday(),
      ).firstWhere((x) => x.title == 'Dekada ’70');
      expect(r.rating, '4.5');
      expect(r.finishedOn, isNotNull);
    });
  });
}
