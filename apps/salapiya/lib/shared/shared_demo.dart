import 'dart:convert';

import '../app/overview_data.dart' show addCivilDays;
import '../local/finance_domain.dart';
import '../p0/exact_money.dart';
import '../prototype/scenarios.dart';
import 'shared_data.dart';
import 'shared_domain.dart';

/// The demo build's groups: synthetic documents in the server's shape, built
/// with the real split and payment rules and dated relative to today. Nothing
/// is stored, and saving a form here doesn't change the sample.

const demoActor = '00000000-0000-4000-8000-00000000a000';
const _amihan = '10000000-0000-4000-8000-000000000001';
const _nico = '10000000-0000-4000-8000-000000000002';
const _tala = '10000000-0000-4000-8000-000000000003';
const _lola = '10000000-0000-4000-8000-000000000004';
const _marco = '10000000-0000-4000-8000-000000000005';

/// The group the shell's "1 payment to confirm" sits in.
const demoHouseholdId = '20000000-0000-4000-8000-000000000001';
const demoNewGroupId = '20000000-0000-4000-8000-000000000005';

class _Group {
  _Group(
    this.today,
    this.id,
    String name,
    Map<String, (String, String)> people, {
    bool archived = false,
  }) : data = {
         'id': id,
         'name': name,
         'owner': _amihan,
         'version': 1,
         'complete': true,
         'archived': archived,
         'people': {
           for (final p in people.entries)
             p.key: {
               'name': p.value.$1,
               'user': p.value.$2 == 'manual'
                   ? null
                   : p.key == _amihan
                   ? demoActor
                   : '${p.key}-user',
               'kind': p.value.$2,
               'active': true,
               'intervals': const [],
               'entitled': const [],
             },
         },
         'bills': <String, dynamic>{},
         'settlements': <String, dynamic>{},
         'activity': <Map<String, dynamic>>[],
       };
  final String today, id;
  final SharedJson data;
  var n = 0;

  String get nextId =>
      '${id.substring(0, 24)}${(++n).toRadixString(16).padLeft(12, '0')}';
  String day(int offset) => addCivilDays(today, offset);
  String at(int offset) => '${day(offset)} 09:00:00+08';
  SharedGroup get group => SharedGroup(data);

  void log(String op, int offset, String id, [String? reason]) {
    (data['activity'] as List).add({
      'id': id,
      'op': op,
      'actor': demoActor,
      'at': at(offset),
      'reason': reason,
    });
    data['version'] = (data['version'] as int) + 1;
  }

  /// One revision through the rules: both axes must equal the total, and an
  /// equal split is the rule's own.
  SharedJson revision(
    String name,
    int offset,
    String total,
    Map<String, String> paid, {
    Iterable<String>? equal,
    Map<String, String>? exact,
    String? reason,
  }) {
    final minor = parsePhp(total);
    final people = group.people;
    final payers = <String, String>{
      for (final p in people.keys) p: '${parsePhp(paid[p] ?? '0')}',
    };
    final shares = exact == null
        ? equalShares(minor, equal ?? people.keys)
        : {for (final e in exact.entries) e.key: '${parsePhp(e.value)}'};
    validateSharedAxis(payers, people, minor);
    validateSharedAxis(shares, people, minor);
    return {
      'id': nextId,
      'name': name,
      'date': day(offset),
      'total': '$minor',
      'paid': payers,
      'shares': shares,
      'method': exact == null ? 'equal' : 'exact',
      'reason': reason,
      'actor': demoActor,
      'at': at(offset),
    };
  }

  String bill(
    String name,
    int offset,
    String total,
    Map<String, String> paid, {
    Iterable<String>? equal,
    Map<String, String>? exact,
    String creator = _amihan,
  }) {
    final first = revision(
      name,
      offset,
      total,
      paid,
      equal: equal,
      exact: exact,
    );
    final id = first['id'] as String;
    (data['bills'] as Map)[id] = {
      'creator': creator,
      'revisions': [first],
      'refunds': <SharedJson>[],
    };
    log('bill', offset, id);
    return id;
  }

  void correct(String bill, SharedJson next) {
    ((data['bills'] as Map)[bill]['revisions'] as List).add(next);
    log('correct', 0, next['id'] as String, next['reason'] as String?);
  }

  void refund(
    String bill,
    int offset,
    String total,
    Map<String, String> received,
    Map<String, String> credits,
    String reason,
  ) {
    final minor = parsePhp(total);
    final back = {
      for (final e in received.entries) e.key: '${parsePhp(e.value)}',
    };
    final parts = {
      for (final e in credits.entries) e.key: '${parsePhp(e.value)}',
    };
    validateSharedAxis(back, group.people, minor);
    validateSharedAxis(parts, group.people, minor);
    final id = nextId;
    ((data['bills'] as Map)[bill]['refunds'] as List).add({
      'id': id,
      'date': day(offset),
      'total': '$minor',
      'received': back,
      'credits': parts,
      'reason': reason,
      'actor': demoActor,
      'at': at(offset),
    });
    log('refund', offset, id, reason);
  }

  /// A logged payment, applied by the rule, then taken through [states].
  String payment(
    String sender,
    String recipient,
    int offset,
    String amount, {
    List<(String state, String? reason)> states = const [],
    bool manual = false,
  }) {
    final minor = parsePhp(amount);
    final applied = group.settlementAllocation(sender, recipient, minor);
    final id = nextId;
    final events = <SharedJson>[
      {'state': 'pending', 'actor': demoActor, 'at': at(offset)},
    ];
    for (final (state, reason) in states) {
      events.add({
        'id': nextId,
        'state': state,
        'actor': demoActor,
        'reason': reason,
        'at': at(offset),
        'manual': manual,
      });
    }
    (data['settlements'] as Map)[id] = {
      'id': id,
      'sender': sender,
      'recipient': recipient,
      'amount': '$minor',
      'date': day(offset),
      'allocations': applied['allocations'],
      'advance': applied['advance'],
      'acknowledge': applied['advance'] != '0' || applied['overNet'] == true,
      'state': states.isEmpty ? 'pending' : states.last.$1,
      'manual': manual,
      'events': events,
    };
    log('report', offset, id);
    return id;
  }
}

/// Everyone's records, oldest first, so each payment applies to what was
/// owed when it was logged.
List<SharedGroup> demoSharedGroups(String today, {bool empty = false}) {
  if (empty) return const [];
  final home = _Group(today, demoHouseholdId, 'Household', {
    _amihan: ('Amihan', 'registered'),
    _nico: ('Nico', 'registered'),
    _tala: ('Tala', 'registered'),
    _lola: ('Lola Ines', 'manual'),
  });
  const adults = [_amihan, _nico, _tala];
  const everyone = [_amihan, _nico, _tala, _lola];
  home.bill('Electricity', -40, '3100.00', {
    _amihan: '3100.00',
  }, equal: everyone);
  home.bill(
    'Groceries',
    -33,
    '2450.75',
    {_tala: '2450.75'},
    equal: adults,
    creator: _tala,
  );
  home.bill(
    'Home internet',
    -30,
    '1699.00',
    {_amihan: '1699.00'},
    exact: {_amihan: '699.00', _nico: '500.00', _tala: '500.00'},
  );
  home.payment(_tala, _amihan, -25, '400.00', states: [('confirmed', null)]);
  home.payment(
    _nico,
    _amihan,
    -22,
    '100.00',
    states: [('confirmed', null), ('reversed', 'Sent it to the wrong person')],
  );
  home.bill('Dinner for Lola', -20, '4000.00', {
    _amihan: '1500.00',
    _nico: '2500.00',
  }, equal: everyone);
  home.payment(
    _lola,
    _amihan,
    -18,
    '775.00',
    states: [('confirmed', null)],
    manual: true,
  );
  home.payment(
    _tala,
    _nico,
    -16,
    '150.00',
    states: [('cancelled', 'Logged the wrong amount')],
  );
  home.payment(
    _nico,
    _amihan,
    -14,
    '200.00',
    states: [('disputed', 'Nothing arrived in my account')],
  );
  final water = home.bill('Water bill', -12, '980.00', {
    _amihan: '980.00',
  }, equal: adults);
  home.correct(
    water,
    home.revision(
      'Water bill',
      -12,
      '1080.00',
      {_amihan: '1080.00'},
      equal: adults,
      reason: 'Typed the wrong amount',
    ),
  );
  final party = home.bill('Party supplies', -9, '1800.00', {
    _amihan: '1800.00',
  }, equal: adults);
  home.refund(
    party,
    -5,
    '300.00',
    {_amihan: '300.00'},
    {_amihan: '100.00', _nico: '100.00', _tala: '100.00'},
    'Returned the balloons',
  );
  home.bill(
    'Weekly market',
    -3,
    '1000.00',
    {_nico: '1000.00'},
    equal: adults,
    creator: _nico,
  );
  home.bill(
    'Car repair',
    -3,
    '6000.00',
    {_nico: '6000.00'},
    equal: adults,
    creator: _nico,
  );
  // The Overview's "Tala reported a payment".
  home.payment(_tala, _amihan, -2, '500.00');
  home.payment(_amihan, _nico, -1, '150.00');

  final trip = _Group(
    today,
    '20000000-0000-4000-8000-000000000002',
    'Boracay trip',
    {
      _amihan: ('Amihan', 'registered'),
      _tala: ('Tala', 'registered'),
      _marco: ('Marco', 'registered'),
    },
  );
  const friends = [_amihan, _tala, _marco];
  trip.bill(
    'Hotel, two nights',
    -60,
    '8400.00',
    {_marco: '8400.00'},
    equal: friends,
    creator: _marco,
  );
  trip.bill(
    'Island hopping',
    -59,
    '3600.00',
    {_tala: '1800.00', _marco: '1800.00'},
    equal: friends,
    creator: _tala,
  );
  trip.bill('Dinner by the beach', -58, '2760.00', {
    _amihan: '2760.00',
  }, equal: friends);

  final reunion = _Group(
    today,
    '20000000-0000-4000-8000-000000000003',
    'Reunion 2025',
    {_amihan: ('Amihan', 'registered'), _nico: ('Nico', 'registered')},
    archived: true,
  );
  reunion.bill(
    'Venue',
    -200,
    '5000.00',
    {_amihan: '5000.00'},
    equal: const [_amihan, _nico],
  );
  reunion.payment(
    _nico,
    _amihan,
    -190,
    '2500.00',
    states: [('confirmed', null)],
  );

  // Left: a partial copy, as the server keeps it for a former member.
  final left = _Group(
    today,
    '20000000-0000-4000-8000-000000000004',
    'Old apartment',
    {_amihan: ('Amihan', 'registered'), _tala: ('Tala', 'registered')},
  );
  left.bill(
    'Move-out cleaning',
    -120,
    '1600.00',
    {_tala: '1600.00'},
    equal: const [_amihan, _tala],
    creator: _tala,
  );
  left.data
    ..['complete'] = false
    ..['version'] = null
    ..['owner'] = _tala
    ..['activity'] = const <SharedJson>[];
  (left.data['people'] as Map)[_amihan]['active'] = false;

  final fresh = _Group(today, demoNewGroupId, 'New group', {
    _amihan: ('Amihan', 'registered'),
  });
  return [
    for (final g in [home, trip, reunion, left, fresh]) g.group,
  ];
}

/// The bill a queued or refused sample command adds.
String _demoCommand(String group, String name, String today) => jsonEncode({
  'contract': 3,
  'group': group,
  'op': 'bill',
  'version': 1,
  'values': {
    'name': name,
    'date': today,
    'total': '180000',
    'paid': {_amihan: '180000'},
    'shares': {_amihan: '60000', _nico: '60000', _tala: '60000'},
    'method': 'equal',
  },
});

SharedSource demoSharedSource(PrototypeSession session) {
  final today = civilToday();
  final empty = session.empty;
  return SharedSource(
    today: today,
    groups: demoSharedGroups(today, empty: empty),
    loaded: true,
    connected: true,
    online: session.scenario != OverviewScenario.waiting,
    complete: session.complete,
    hidden: session.hideAmounts,
    amount: session.amount,
    writer: const DemoSharedWriter(),
    profileName: session.profile.name,
    actor: demoActor,
    pendingCount: session.pending ? 1 : 0,
    needsReview: session.needsReview,
    syncLabel: session.syncLabel,
    demo: true,
    drafts: empty
        ? const []
        : [
            {
              'id': 'demo-draft',
              'group_id': demoHouseholdId,
              'payload': jsonEncode({
                'title': 'Add shared expense',
                'op': 'bill',
                'fields': {'name': 'Gas refill', 'total': '950.00'},
              }),
            },
          ],
    intents: [
      if (session.pending)
        {
          'id': 'demo-queued',
          'group_id': demoHouseholdId,
          'state': 'pending',
          'payload': _demoCommand(demoHouseholdId, 'Birthday cake', today),
        },
      if (session.needsReview)
        {
          'id': 'demo-refused',
          'group_id': demoHouseholdId,
          'state': 'review',
          'reason': 'Group changed; refresh and review',
          'payload': _demoCommand(demoHouseholdId, 'Birthday cake', today),
        },
    ],
  );
}

/// The demo's forms run the same checks and save nothing.
class DemoSharedWriter implements SharedWriter {
  const DemoSharedWriter();
  @override
  String? get actor => demoActor;
  @override
  bool get online => true;
  @override
  Future<String> submit(
    String group,
    String op,
    SharedJson values, {
    int version = 0,
    String? id,
  }) async => id ?? newLocalId();
  @override
  Future<void> retry(String id) async {}
  @override
  Future<SharedJson> reviewInvitation(String code) async =>
      reject('The demo can’t join a group. Try this in the real app.');
  @override
  Future<void> draft(String id, String group, SharedJson values) async {}
  @override
  Future<SharedJson?> readDraft(String id) async => id == 'demo-draft'
      ? {
          'title': 'Add shared expense',
          'op': 'bill',
          'fields': {'name': 'Gas refill', 'total': '950.00'},
        }
      : null;
  @override
  Future<void> discardDraft(String id) async {}
}

/// The bill the sample's own record is linked to: the user paid it from the
/// bank, so Money, the record page and Bills all show the same bill.
SharedDemoLink demoLinkedBill(String today) {
  final g = demoSharedGroups(today).first;
  final me = g.participant(demoActor)!;
  final bill = g.bills.keys.firstWhere(
    (b) => g.revision(b)['name'] == 'Water bill',
  );
  final r = g.revision(bill);
  return (
    group: g.id,
    bill: bill,
    revision: r['id'] as String,
    name: r['name'] as String,
    date: r['date'] as String,
    paid: phpDecimal(sharedMinor(r['paid'][me])),
    part: phpDecimal(sharedMinor(r['shares'][me])),
  );
}

typedef SharedDemoLink = ({
  String group,
  String bill,
  String revision,
  String name,
  String date,
  String paid,
  String part,
});

/// The Overview's Shared row, from the same payment Payments lists.
String demoToConfirmLine(String today, String Function(BigInt) amount) {
  final g = demoSharedGroups(today).first;
  final waiting = sharedPaymentRows(
    g,
    g.participant(demoActor),
    today,
  ).firstWhere((p) => p.status == PaymentStatus.toConfirm);
  return '${waiting.from} logged ${amount(waiting.amount)} · ${g.name}';
}
