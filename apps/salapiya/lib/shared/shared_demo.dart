import 'dart:convert';

import '../app/overview_data.dart' show addCivilDays;
import '../app/overview_demo.dart' show demoSample;
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
const _rosa = '10000000-0000-4000-8000-000000000006';
const _jun = '10000000-0000-4000-8000-000000000007';

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
    this.owner = _amihan,
    int started = -240,
  }) : data = {
         'id': id,
         'name': name,
         'owner': owner,
         'version': 1,
         'complete': true,
         'archived': archived,
         'people': {
           for (final p in people.entries)
             p.key: {
               'name': p.value.$1,
               'user': _user(p.key, p.value.$2),
               'kind': p.value.$2,
               'active': true,
               'intervals': <SharedJson>[],
               'entitled': const [],
             },
         },
         'bills': <String, dynamic>{},
         'settlements': <String, dynamic>{},
         'activity': <Map<String, dynamic>>[],
       } {
    log('create', started, nextId, by: owner);
    _interval(owner, {'joined': at(started), 'role': 'owner'});
    for (final p in people.entries) {
      if (p.key == owner) continue;
      if (p.value.$2 == 'manual') {
        log('manual', started + 1, nextId, by: owner);
      } else {
        log('invite', started, nextId, by: owner);
        log('accept', started + 1, nextId, by: p.key);
        _interval(p.key, {
          'joined': at(started + 1),
          'role': 'member',
          'historyPolicy': 1,
        });
      }
    }
  }
  final String today, id, owner;
  final SharedJson data;
  var n = 0;

  static String? _user(String person, String kind) => kind == 'manual'
      ? null
      : person == _amihan
      ? demoActor
      : '$person-user';

  void _interval(String person, SharedJson entry) =>
      ((data['people'] as Map)[person]['intervals'] as List).add(entry);

  String get nextId =>
      '${id.substring(0, 24)}${(++n).toRadixString(16).padLeft(12, '0')}';
  String day(int offset) => addCivilDays(today, offset);
  String at(int offset) => '${day(offset)} 09:00:00+08';
  SharedGroup get group => SharedGroup(data);

  /// One line of the group's history, by the person who did it.
  void log(String op, int offset, String id, {String? reason, String? by}) {
    (data['activity'] as List).add({
      'id': id,
      'op': op,
      'actor': (data['people'] as Map)[by ?? owner]?['user'],
      'at': at(offset),
      'reason': reason,
    });
    data['version'] = (data['version'] as int) + 1;
  }

  /// [person] leaves. Their history and balance stay (DOMAIN_RULES §51).
  void leave(String person, int offset, String reason) {
    final p = (data['people'] as Map)[person] as Map;
    p['active'] = false;
    p['entitled'] = (data['bills'] as Map).keys.toList();
    _interval(person, {
      'left': at(offset),
      'actor': p['user'],
      'reason': reason,
    });
    log('leave', offset, nextId, reason: reason, by: person);
  }

  /// The account behind [person] was deleted, as the server records it: the
  /// bills and the balance stay, and only the name and access change.
  void deleteAccount(String person, int offset) {
    final p = (data['people'] as Map)[person] as Map;
    p
      ..['name'] = 'Deleted participant'
      ..['user'] = null
      ..['kind'] = 'deleted'
      ..['active'] = false
      ..['entitled'] = (data['bills'] as Map).keys.toList();
    _interval(person, {
      'left': at(offset),
      'reason': 'Provider identity deleted',
    });
    log(
      'identity_deleted',
      offset,
      nextId,
      reason: 'Shared evidence retained; ownerless administration archived',
    );
  }

  /// [next] becomes the owner, and the owner before them a member.
  void transfer(String next, int offset, String reason) {
    final was = data['owner'] as String;
    data['owner'] = next;
    final actor = (data['people'] as Map)[was]['user'];
    _interval(was, {
      'role': 'member',
      'changedAt': at(offset),
      'actor': actor,
      'reason': reason,
    });
    _interval(next, {
      'role': 'owner',
      'changedAt': at(offset),
      'actor': actor,
      'reason': reason,
    });
    log('transfer', offset, nextId, reason: reason, by: was);
  }

  /// Puts the history in order: each line was added as the sample was built.
  void finish() {
    (data['activity'] as List).sort(
      (a, b) => (a['at'] as String).compareTo(b['at'] as String),
    );
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
    log('bill', offset, id, by: creator);
    return id;
  }

  void correct(String bill, SharedJson next, int offset, {String? by}) {
    ((data['bills'] as Map)[bill]['revisions'] as List).add(next);
    log(
      'correct',
      offset,
      next['id'] as String,
      reason: next['reason'] as String?,
      by: by,
    );
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
    log('refund', offset, id, reason: reason);
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
    final people = data['people'] as Map;
    // The owner logs and answers for someone who isn't registered.
    String? user(String person) => people[person]['kind'] == 'registered'
        ? people[person]['user'] as String?
        : people[owner]['user'] as String?;
    final events = <SharedJson>[
      {'state': 'pending', 'actor': user(sender), 'at': at(offset)},
    ];
    log(
      'report',
      offset,
      id,
      by: people[sender]['kind'] == 'registered' ? sender : owner,
    );
    for (final (state, reason) in states) {
      final by = state == 'cancelled' ? sender : recipient;
      final event = nextId;
      events.add({
        'id': event,
        'state': state,
        'actor': user(by),
        'reason': reason,
        'at': at(offset),
        'manual': manual,
      });
      log(
        'resolve',
        offset,
        event,
        reason: reason,
        by: people[by]['kind'] == 'registered' ? by : owner,
      );
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
    _rosa: ('Rosa', 'registered'),
  });
  const adults = [_amihan, _nico, _tala];
  const everyone = [_amihan, _nico, _tala, _lola];
  // Rosa left with a balance: leaving doesn't forgive it.
  home.bill(
    'Moving truck',
    -44,
    '1500.00',
    {_amihan: '1500.00'},
    equal: const [_amihan, _rosa],
  );
  home.leave(_rosa, -42, 'Moved out in September');
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
    -11,
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
  // Corrected after the user added them to Money, so My Records has one to
  // look at and one the user decided to keep. The amounts stay the same.
  for (final (name, total, reason) in const [
    ('Weekly market', '1000.00', 'Added the store’s name'),
    ('Car repair', '6000.00', 'Added the shop’s receipt'),
  ]) {
    final id = home.bill(
      name,
      -3,
      total,
      {_nico: total},
      equal: adults,
      creator: _nico,
    );
    home.correct(
      id,
      home.revision(
        name,
        -3,
        total,
        {_nico: total},
        equal: adults,
        reason: reason,
      ),
      -2,
      by: _nico,
    );
  }
  // The Overview's "Tala reported a payment".
  home.payment(_tala, _amihan, -2, '500.00');
  home.payment(_amihan, _nico, -1, '150.00');
  // One invitation still open, one long past its seven days.
  home.log('invite', -2, home.nextId);
  home.log('invite', -30, home.nextId);

  final trip = _Group(
    today,
    '20000000-0000-4000-8000-000000000002',
    'Boracay trip',
    {
      _amihan: ('Amihan', 'registered'),
      _tala: ('Tala', 'registered'),
      _marco: ('Marco', 'registered'),
      _jun: ('Jun', 'registered'),
    },
    // The user is a member here, not the owner.
    owner: _marco,
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
  trip.bill(
    'Van rental',
    -57,
    '1200.00',
    {_tala: '1200.00'},
    equal: const [_amihan, _tala, _jun],
    creator: _tala,
  );
  // Jun's account was deleted later. The bill and his balance stay.
  trip.deleteAccount(_jun, -40);

  final reunion = _Group(
    today,
    '20000000-0000-4000-8000-000000000003',
    'Reunion 2025',
    {_amihan: ('Amihan', 'registered'), _nico: ('Nico', 'registered')},
    archived: true,
    owner: _nico,
  );
  reunion.transfer(_amihan, -210, 'Amihan is keeping the records now');
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
  reunion.log('archive', -180, reunion.nextId, reason: 'Reunion is over');

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
  home.finish();
  trip.finish();
  reunion.finish();
  fresh.finish();
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
  final sample = demoSample(today, empty: empty);
  final current = [
    for (final r in sample.current)
      if (r.values.containsKey('sharedGroup')) r,
  ];
  return SharedSource(
    today: today,
    groups: demoSharedGroups(today, empty: empty),
    current: current,
    reviews: empty ? const [] : _demoReviews(today, current),
    accountName: (id) =>
        sample.accounts.where((a) => a.id == id).firstOrNull?.name,
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
  @override
  Future<void> keepRecord({
    required String id,
    required String group,
    required String bill,
    required String record,
    required String stamp,
    required String reason,
  }) async {}
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

/// The user's own record of a bill, as it was when they added it: the first
/// version, so a later correction shows in My Records.
Map<String, String> demoPrivateBill(String today, String name) {
  final g = demoSharedGroups(today).first;
  final me = g.participant(demoActor)!;
  final id = g.bills.keys.firstWhere((b) => g.revision(b)['name'] == name);
  final first = object((g.bills[id]['revisions'] as List).first);
  return {
    'name': 'Shared bill · $name',
    'date': first['date'] as String,
    'sharedMode': 'bill',
    'sharedAccounting': '2',
    'sharedGroup': g.id,
    'sharedKey': id,
    'sharedRevision': first['id'] as String,
    'fundingAmount': phpDecimal(sharedMinor(first['paid'][me])),
    'shareAmount': phpDecimal(sharedMinor(first['shares'][me])),
    'account': '',
    'category': 'category-food',
    'reason': '',
    'funding': 'cash',
    'acknowledgeFunding': 'false',
  };
}

/// The user's own record of a confirmed payment they received.
Map<String, String> demoPrivatePayment(String today, String amount) {
  final g = demoSharedGroups(today).first;
  final minor = '${parsePhp(amount)}';
  final s = object(
    g.settlements.values.firstWhere(
      (p) => p['amount'] == minor && p['state'] == 'confirmed',
    ),
  );
  return {
    'name': 'Shared payment · ${g.name}',
    'date': s['date'] as String,
    'sharedMode': 'payment',
    'sharedAccounting': '2',
    'sharedGroup': g.id,
    'sharedKey': s['id'] as String,
    'sharedRevision': s['id'] as String,
    'fundingAmount': amount,
    'shareAmount': '0.00',
    'category': 'category-food',
    'reason': '',
    'funding': 'cash',
    'acknowledgeFunding': 'false',
    'direction': 'in',
  };
}

/// The checks the user made in the sample: one that still holds, and one
/// that came back from a backup.
List<SharedJson> _demoReviews(String today, List<LocalRevision> current) {
  final g = demoSharedGroups(today).first;
  String bill(String name) =>
      g.bills.keys.firstWhere((b) => g.revision(b)['name'] == name);
  final repair = bill('Car repair');
  final record = current.firstWhere((r) => r.values['sharedKey'] == repair);
  return [
    {
      'id': 'demo-review',
      'group_id': g.id,
      'bill_id': repair,
      'private_revision': record.id,
      'source_stamp': sharedSourceStamp(object(g.bills[repair])),
      'reason': 'The amount didn’t change, so my record is right',
      'recorded_at': '${addCivilDays(today, -1)} 01:00:00+00',
    },
    {
      'id': 'demo-review-backup',
      'group_id': g.id,
      'bill_id': bill('Water bill'),
      'private_revision': 'earlier',
      'source_stamp': 'earlier',
      'reason': 'Checked before I restored a backup',
      'recorded_at': '${addCivilDays(today, -20)} 01:00:00+00',
      'historicalOnly': true,
    },
  ];
}

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
