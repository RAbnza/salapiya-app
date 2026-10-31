import '../features/finance/presentation/financial_review.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/editorial.dart';
import '../app/demo_routes.dart';
import '../design_system/theme.dart';
import '../features/finance/presentation/financial_widgets.dart';
import '../local/finance_domain.dart';
import '../local/local_runtime.dart';
import '../local/local_store.dart';
import '../local/local_finance_controller.dart';
import 'shared_bill_form.dart';
import 'shared_data.dart';
import 'shared_domain.dart';
import 'shared_hub.dart';
import 'shared_pages.dart';
import 'shared_repository.dart';

/// Shares a purchase already in Money. It stays where it is: the group gets a
/// bill and the user's own record is linked to it, so nothing is logged twice.
Future<void> sharePrivatePurchase(
  BuildContext context,
  LocalFinancialController controller,
  String purchaseId,
) async {
  final snapshot = await controller.store.snapshot();
  final purchase = snapshot.current
      .where(
        (r) =>
            r.id == purchaseId &&
            r.kind == 'expense' &&
            !r.values.containsKey('sharedGroup'),
      )
      .firstOrNull;
  if (purchase == null) {
    reject('This purchase is already shared or has changed.');
  }
  final binding = await controller.store.connection();
  if (binding == null || binding['phase'] != 'connected') {
    reject(
      'Connect this profile with Google to share it. Your purchase stays saved.',
    );
  }
  if (!context.mounted) return;
  final hub = SharedScope.maybeOf(context);
  final groups = hub == null
      ? const <SharedGroupRow>[]
      : sharedGroupRows(hub.source()).where((r) => r.current).toList();
  if (hub == null || groups.isEmpty) {
    reject('Add or join a group first. Your purchase stays saved.');
  }
  await openDemoPage<void>(
    context,
    SharedBillForm(
      hub: hub,
      group: groups.length == 1 ? groups.single.group : null,
      purchase: SharedPurchase(
        id: purchase.id,
        name: purchase.title,
        date: purchase.date,
        total: purchase.amount,
      ),
    ),
    'shared/adopt-purchase',
    title: 'Share your saved purchase',
  );
}

/// The forms that wait for Chat 11. A class of its own, because the bill and
/// payment pages open them too.
class SharedNativeForms implements SharedPrivateActions {
  SharedNativeForms(this.session, this.repo);
  final LocalSession session;
  final SharedRepository repo;
  String money(BigInt n) => session.amount(n);

  @override
  Future<void> run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Review needed'),
            content: Text(
              e is LocalRuleException ? e.message : 'The request could not complete. Saved drafts and actual spending remain on this device. Reconnect and retry the original command.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> form(
    BuildContext context,
    String title,
    List<SharedField> fields,
    Future<void> Function(Map<String, String>) save, {
    String? id,
    String? group,
    SharedJson metadata = const {},
    List<String> Function(Map<String, String>)? preview,
  }) async {
    final saved = id == null
        ? null
        : (await repo.store.db.getAll(
            'SELECT payload FROM shared_draft WHERE id=?',
            [id],
          )).firstOrNull;
    final restored = saved == null
        ? <String, dynamic>{}
        : object(object(jsonDecode(saved['payload'] as String))['fields']);
    if (!context.mounted) return;
    await openDemoPage<void>(
      context,
      _SharedForm(
        title: title,
        fields: [
          for (final f in fields)
            SharedField(
              f.key,
              f.label,
              value: restored[f.key] as String? ?? f.value,
              options: f.options,
            ),
        ],
        onSave: save,
        preview: preview,
        onDraft: id == null
            ? null
            : (values) => repo.draft(id, group ?? '', {
                'title': title,
                'fields': values,
                ...metadata,
              }),
      ),
      'shared/editor',
    );
  }

  Future<void> invitation(
    BuildContext context,
    SharedGroup g, {
    String? participant,
  }) => form(
    context,
    participant == null
        ? 'Invite a registered person'
        : 'Nominate manual participant',
    [const SharedField('email', 'Verified Google email')],
    (v) async {
      final token = SharedRepository.invitationToken();
      final invitationId = await repo.submit(g.id, 'invite', {
        'email': v['email'],
        'hash': SharedRepository.tokenHash(token),
        'participant': ?participant,
      }, version: g.version);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Share this invitation securely'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText('${g.id}.$token'),
              const SizedBox(height: 12),
              const Text(
                'Single use · seven days · intended verified Google recipient only. The recipient can paste this code in Join group. This code is shown once.',
              ),
              const SizedBox(height: 12),
              SelectableText('Invitation reference: $invitationId'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    },
  );
  Future<void> lifecycle(
    BuildContext context,
    SharedGroup g,
    String op, {
    String? participant,
  }) => form(
    context,
    op == 'archive'
        ? 'Archive / restore group'
        : '${op[0].toUpperCase()}${op.substring(1)} participant',
    [
      if (participant == null && op != 'archive')
        SharedField(
          'participant',
          'Participant',
          options: {
            for (final p in g.people.entries) p.key: p.value['name'] as String,
          },
        ),
      if (op == 'archive')
        SharedField(
          'archived',
          'Group state',
          value: g.archived ? 'false' : 'true',
          options: const {'true': 'Archived', 'false': 'Active'},
        ),
      const SharedField('reason', 'Reason'),
    ],
    (v) async {
      await repo.submit(g.id, op, {
        'reason': v['reason'],
        if (op == 'archive')
          'archived': v['archived'] == 'true'
        else
          'participant': participant ?? v['participant'],
      }, version: g.version);
    },
  );
  @override
  Future<void> privateBill(
    BuildContext context,
    SharedGroup g,
    String bill,
  ) async {
    await privateEffect(context, g, bill, 'bill');
  }

  @override
  Future<void> retainEvidence(
    BuildContext context,
    SharedGroup g,
    String bill,
  ) async {
    final snapshot = await repo.store.snapshot();
    final source = snapshot.current
        .where(
          (r) =>
              r.values['sharedGroup'] == g.id &&
              r.values['sharedKey'] == bill &&
              r.values['sharedMode'] == 'bill',
        )
        .firstOrNull;
    if (source == null) {
      reject('Adopt this bill before reviewing a private difference.');
    }
    if (!context.mounted) return;
    await form(
      context,
      'Retain accepted private evidence',
      [const SharedField('reason', 'Attributed review reason')],
      (v) async {
        if (!repo.online) {
          reject(
            'A current online identity is required for private source review.',
          );
        }
        await session.runtime.connected.flow!.client.rpc(
          'p3_retain_private_evidence',
          params: {
            'command_id': newLocalId(),
            'profile_id': repo.store.owner,
            'group_id': g.id,
            'bill_id': bill,
            'private_revision': source.id,
            'source_stamp': sharedSourceStamp(object(g.bills[bill])),
            'reason': v['reason'],
          },
        );
      },
    );
  }

  @override
  Future<void> privateEffect(
    BuildContext context,
    SharedGroup g,
    String key,
    String mode,
  ) async {
    await session.runtime.connected.syncNow();
    final store = repo.store, snapshot = await store.snapshot();
    final me = g.participant(repo.actor ?? '');
    if (me == null) reject('Your group identity is unavailable.');
    final linked = snapshot.current
        .where(
          (r) =>
              r.values['sharedGroup'] == g.id &&
              r.values['sharedKey'] == key &&
              r.values['sharedMode'] == mode,
        )
        .firstOrNull;
    final integratedDraft = mode == 'bill'
        ? await store.draft('shared-purchase:$key')
        : null;
    if (linked == null &&
        integratedDraft != null &&
        !snapshot.current.any(
          (r) =>
              r.id == (integratedDraft['values'] as Map)['privateSource'] &&
              r.kind == 'expense' &&
              !r.values.containsKey('sharedGroup'),
        )) {
      reject(
        'The saved private purchase changed. Review its current Money history before adopting this bill. Actual spending is preserved.',
      );
    }
    final payment = snapshot.current
        .where(
          (r) =>
              r.values['sharedGroup'] == g.id &&
              r.values['sharedKey'] == key &&
              r.values['sharedMode'] == 'payment',
        )
        .firstOrNull;
    final clearing = snapshot.current
        .where(
          (r) =>
              r.values['sharedGroup'] == g.id &&
              r.values['sharedKey'] == key &&
              r.values['sharedMode'] == 'clear',
        )
        .firstOrNull;
    final source = mode == 'bill'
        ? g.revision(key)
        : mode == 'refund'
        ? g.bills.values
              .expand((b) => b['refunds'] as List)
              .where((f) => f['id'] == key)
              .first
        : g.settlements[key];
    final refundBill = mode == 'refund'
        ? g.bills.entries
              .where(
                (b) => (b.value['refunds'] as List).any((f) => f['id'] == key),
              )
              .first
        : null;
    final refundCoverage =
        refundBill != null &&
        snapshot.current.any(
          (r) =>
              r.values['sharedMode'] == 'bill' &&
              r.values['sharedGroup'] == g.id &&
              r.values['sharedKey'] == refundBill.key &&
              r.values['sharedRevision'] == g.revision(refundBill.key)['id'],
        );
    final outgoing = ['payment', 'clear', 'unclear'].contains(mode)
        ? source['sender'] == me
        : false;
    final paid = mode == 'bill'
        ? sharedMinor(source['paid'][me] ?? '0')
        : mode == 'refund'
        ? sharedMinor(source['received'][me] ?? '0')
        : sharedMinor(source['amount']);
    final share = mode == 'bill'
        ? sharedMinor(source['shares'][me] ?? '0')
        : mode == 'refund'
        ? sharedMinor(source['credits'][me] ?? '0')
        : BigInt.zero;
    if (!context.mounted) return;
    await form(
      context,
      'Private Money · $mode',
      [
        SharedField(
          'account',
          'Your private account',
          value: linked?.values['account'] ?? '',
          options: {
            '': 'No cash funding',
            for (final a in snapshot.accounts.where((a) => !a.archived))
              a.id: a.name,
          },
        ),
        SharedField(
          'category',
          'Your expense category',
          value: linked?.values['category'] ?? 'category-food',
          options: {
            for (final c in snapshot.categories.where(
              (c) => c.kind == 'expense',
            ))
              c.id: c.name,
          },
        ),
        if (mode == 'bill' && linked == null)
          SharedField(
            'existing',
            'Adopt existing purchase',
            value: integratedDraft == null
                ? ''
                : (integratedDraft['values'] as Map)['privateSource']
                          as String? ??
                      '',
            options: {
              '': 'Record new cash / unpaid allocation',
              for (final r in snapshot.current.where(
                (r) =>
                    r.kind == 'expense' && !r.values.containsKey('sharedGroup'),
              ))
                r.id: '${r.title} · ${phpDecimal(r.amount)} PHP',
            },
          ),
        if (mode == 'payment' && linked == null)
          SharedField(
            'existingPayment',
            'Reuse an already recorded payment',
            options: {
              '': 'Record a new actual cash movement',
              for (final r in snapshot.current.where(
                (r) =>
                    r.values['sharedMode'] == 'payment' &&
                    r.values['sharedGroup'] == g.id &&
                    r.values['sharedKey'] != key &&
                    [
                      'cancelled',
                      'reversed',
                    ].contains(g.settlements[r.values['sharedKey']]?['state']),
              ))
                r.id:
                    '${r.title} · ${r.date} · ${r.values['fundingAmount']} PHP · same parties, date, account and amount required',
            },
          ),
        if (mode == 'refund' && linked == null)
          SharedField(
            'existingCardRefund',
            'Adopt an actual card refund (optional)',
            options: {
              '': 'Record cash refund / no card credit',
              for (final r in snapshot.current.where(
                (r) =>
                    financeType(r) == 'cardRefund' &&
                    !r.values.containsKey('sharedGroup'),
              ))
                r.id: '${r.title} · ${phpDecimal(r.amount)} PHP · ${r.date}',
            },
          ),
        SharedField(
          'fundingAmount',
          'Actual private funding (PHP)',
          value: linked?.values['fundingAmount'] ?? phpDecimal(paid),
        ),
        SharedField(
          'shareAmount',
          'Your recognized consumption (PHP)',
          value: phpDecimal(share),
        ),
        SharedField(
          'date',
          'Actual private date (YYYY-MM-DD)',
          value: linked?.date ?? source['date'] as String,
        ),
        if (linked != null)
          const SharedField(
            'acknowledgeFunding',
            'Actual funding correction consent',
            value: 'false',
            options: {
              'false': 'Keep actual accepted funding',
              'true': 'I acknowledge changing actual funding from the accepted private record',
            },
          ),
        const SharedField(
          'acknowledge',
          'Negative tracked balance consent',
          value: 'false',
          options: {
            'false': 'No negative balance acknowledged',
            'true': 'I acknowledge the negative tracked account balance',
          },
        ),
        const SharedField('reason', 'Reason / source review'),
      ],
      (v) async {
        final old =
            linked ??
            snapshot.current
                .where(
                  (r) =>
                      r.id ==
                      (v['existing'] ??
                          v['existingPayment'] ??
                          v['existingCardRefund']),
                )
                .firstOrNull;
        // Cash forms retain unused card selector values. Only the validated
        // immutable transaction type establishes actual card funding.
        final cardFunded = sharedSourceUsesCard(old);
        final values = <String, String>{
          'name': 'Shared $mode · ${mode == 'bill' ? source['name'] : g.name}',
          'date': v['date']!,
          'sharedMode': mode,
          'sharedAccounting': '2',
          'sharedGroup': g.id,
          'sharedKey': key,
          'sharedRevision': source['id'] as String,
          'fundingAmount': v['fundingAmount']!,
          'shareAmount': v['shareAmount']!,
          'account': v['account']!,
          'category': v['category']!,
          'reason': v['reason']!,
          'funding': cardFunded ? 'card' : 'cash',
          if (cardFunded) 'card': old!.values['card']!,
          'acknowledge': v['acknowledge']!,
          'acknowledgeFunding': v['acknowledgeFunding'] ?? 'false',
          if (old != null) ...{
            'source': old.id,
            'sourceVersion': '${old.number}',
          },
          if (['payment', 'clear', 'unclear'].contains(mode))
            'direction': outgoing ? 'out' : 'in',
          if (mode == 'clear') 'paymentSource': payment?.id ?? '',
          if (mode == 'unclear') 'paymentSource': clearing?.id ?? '',
          if (refundBill != null) ...{
            'billSource': refundBill.key,
            'billRevision': g.revision(refundBill.key)['id'] as String,
            'coverage': refundCoverage ? 'adopted' : 'clearing',
          },
        };
        final command = LocalCommand(
          id: newLocalId(),
          owner: store.owner,
          expectedVersion: snapshot.version,
          kind: 'shared',
          values: values,
        );
        final plan = planLocal(snapshot, command);
        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Review private money effects'),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: FinancialReview(
                  plan: plan,
                  snapshot: snapshot,
                  amount: session.localFinance.amount,
                  hidden: session.hideAmounts,
                  commandId: command.id,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Edit'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save my private action'),
              ),
            ],
          ),
        );
        if (confirmed != true) reject('Private action was not saved.');
        await store.commit(command);
        await session.localFinance.reload();
      },
    );
  }
}

/// The tabs that keep their old content until Chat 11.
class NativeSharedScreen extends StatefulWidget {
  const NativeSharedScreen({
    super.key,
    required this.session,
    required this.hub,
    required this.group,
    required this.tab,
  });
  final LocalSession session;
  final SharedHub hub;
  final SharedGroup group;
  final String tab;
  @override
  State<NativeSharedScreen> createState() => _NativeSharedScreenState();
}

class _NativeSharedScreenState extends State<NativeSharedScreen> {
  SharedRepository get repo => widget.hub.repo!;
  SharedNativeForms get forms => widget.hub.private as SharedNativeForms;
  bool projected = false;
  int page = 0;
  String get tab => widget.tab;

  @override
  void didUpdateWidget(NativeSharedScreen old) {
    super.didUpdateWidget(old);
    if (old.tab != tab || old.group.id != widget.group.id) page = 0;
  }

  String money(BigInt n) => widget.session.amount(n);

  /// A group the user left is a partial copy, and the rules can refuse to work
  /// it out. The tab then lists nothing rather than failing to draw.
  List<SharedEdge> partial(List<SharedEdge> Function() read) {
    try {
      return read();
    } catch (_) {
      return const [];
    }
  }

  Future<void> run(Future<void> Function() action) =>
      forms.run(context, action);
  Future<void> form(
    String title,
    List<SharedField> fields,
    Future<void> Function(Map<String, String>) save,
  ) => forms.form(context, title, fields, save);
  Future<void> invitation(SharedGroup g, {String? participant}) =>
      forms.invitation(context, g, participant: participant);
  Future<void> lifecycle(SharedGroup g, String op, {String? participant}) =>
      forms.lifecycle(context, g, op, participant: participant);
  Future<void> privateBill(SharedGroup g, String bill) =>
      forms.privateBill(context, g, bill);
  Future<void> privateEffect(SharedGroup g, String key, String mode) =>
      forms.privateEffect(context, g, key, mode);

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final me = g.participant(repo.actor ?? '');
    final active = g.active(me);
    final owner = g.data['owner'] == me && me != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tab == 'Balances') ...[
          SharedPositionsCard(source: widget.hub.source(), group: g),
          const SizedBox(height: Space.lg),
          const SectionHeading('Reciprocal pair balances'),
          for (final pair in partial(() => g.reciprocalPairs))
            FinancialLine(
              '${g.personName(pair.sender)} → ${g.personName(pair.recipient)}',
              'Confirmed source obligations after reciprocal netting',
              value: money(pair.amount),
              icon: Icons.compare_arrows,
              color: Palette.mint,
            ),
          const FinanceNotice(
            'Suggestions are nonposting proposals requiring agreement. Paying an unrelated person does not erase a source obligation. Disputes pause suggestions.',
          ),
          for (final e in partial(() => g.suggestions))
            FinancialLine(
              '${g.personName(e.sender)} → ${g.personName(e.recipient)}',
              'Suggestion · agreement required',
              value: money(e.amount),
              icon: Icons.compare_arrows,
              color: Palette.mint,
            ),
          const SectionHeading('Pairwise source explanations'),
          for (final e in partial(g.edges))
            FinancialLine(
              '${g.personName(e.sender)} → ${g.personName(e.recipient)}',
              e.bill == null
                  ? 'Advance · ${e.source}'
                  : '${g.revision(e.bill!)['name']} · source ${e.source}',
              value: money(e.amount),
              icon: Icons.link,
              color: Palette.peach,
            ),
        ],
        if (tab == 'People') ...[
          if (owner)
            Wrap(
              children: [
                TextButton(
                  onPressed: repo.online
                      ? () => run(
                          () => form(
                            'Add manual participant',
                            [const SharedField('name', 'Participant name')],
                            (v) async {
                              await repo.submit(g.id, 'manual', {
                                'participant': newLocalId(),
                                'name': v['name'],
                              }, version: g.version);
                            },
                          ),
                        )
                      : null,
                  child: const Text('Add manual person'),
                ),
                TextButton(
                  onPressed: repo.online
                      ? () => run(() => invitation(g))
                      : null,
                  child: const Text('Invite registered person'),
                ),
              ],
            ),
          for (final p in g.people.entries)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FinancialLine(
                  p.value['name'] as String,
                  '${p.value['kind']} · ${p.value['active'] == true ? 'active' : 'former'}${g.data['owner'] == p.key ? ' · owner' : ''}',
                  icon: Icons.person_outline,
                  color: Palette.peach,
                ),
                if (owner && p.value['kind'] == 'manual')
                  TextButton(
                    onPressed: () =>
                        run(() => invitation(g, participant: p.key)),
                    child: const Text('Nominate verified claim'),
                  ),
                Text('Membership history: ${jsonEncode(p.value['intervals'])}'),
              ],
            ),
        ],
        if (tab == 'Private review') ...[
          const FinanceNotice(
            'Private adoption is independent from group acceptance. No other member’s ledger is changed. Card funding adopts an already recorded private card purchase or refund.',
          ),
          for (final r in repo.reviews.where((r) => r['group_id'] == g.id))
            FinancialLine(
              g.bills.containsKey(r['bill_id'])
                  ? g.revision(r['bill_id'] as String)['name'] as String
                  : 'Historical shared source',
              '${r['historicalOnly'] == true ? 'Historical archive review · current authorization must be reviewed again' : 'Accepted private retained-evidence review'}\n${r['reason']}\n${r['recorded_at']}',
              icon: Icons.history,
              color: Palette.mint,
            ),
          for (final b in g.bills.keys)
            FinancialLine(
              g.revision(b)['name'] as String,
              'Review your own funding, consumption and versioned source',
              icon: Icons.lock_outline,
              color: Palette.mint,
              onTap: () => run(() => privateBill(g, b)),
            ),
        ],
        if (tab == 'History') ...[
          for (final e
              in (g.data['activity'] as List).reversed.skip(page * 50).take(50))
            FinancialLine(
              e['op'] as String,
              '${e['at']} · ${e['reason'] ?? ''}',
              icon: Icons.history,
              color: Palette.mint,
            ),
          TextButton(
            onPressed: () => run(() async {
              final text = jsonEncode({
                'format': 'salapiya-group-history-1',
                'restorable': false,
                'document': g.data,
              });
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Authorized history copied · not a restorable private backup.',
                    ),
                  ),
                );
              }
            }),
            child: const Text('Copy authorized group history export'),
          ),
        ],
        if (tab == 'Lifecycle')
          Wrap(
            spacing: 8,
            children: [
              if (owner) ...[
                TextButton(
                  onPressed: () => run(() => lifecycle(g, 'transfer')),
                  child: const Text('Transfer ownership'),
                ),
                TextButton(
                  onPressed: () => run(() => lifecycle(g, 'remove')),
                  child: const Text('Remove participant'),
                ),
                TextButton(
                  onPressed: () => run(() => lifecycle(g, 'archive')),
                  child: Text(g.archived ? 'Restore group' : 'Archive group'),
                ),
                TextButton(
                  onPressed:
                      !(g.data['activity'] as List).any(
                        (e) => e['op'] == 'invite',
                      )
                      ? null
                      : () => run(
                          () => form(
                            'Revoke invitation',
                            [
                              SharedField(
                                'invitation',
                                'Issued invitation',
                                options: {
                                  for (final e
                                      in (g.data['activity'] as List).where(
                                        (e) => e['op'] == 'invite',
                                      ))
                                    e['id'] as String:
                                        '${e['at']} · reference ${(e['id'] as String).substring(0, 8)}',
                                },
                              ),
                            ],
                            (v) async {
                              await repo.submit(g.id, 'revoke', {
                                'invitation': v['invitation'],
                              }, version: g.version);
                            },
                          ),
                        ),
                  child: const Text('Revoke invitation'),
                ),
              ],
              if (active && !owner)
                TextButton(
                  onPressed: () =>
                      run(() => lifecycle(g, 'leave', participant: me)),
                  child: const Text('Leave group'),
                ),
              const FinanceNotice(
                'An unavailable owner does not block ordinary member bills. Ownership cannot be taken over by peers. Retained history does not restore membership authority.',
              ),
            ],
          ),
        if (tab == 'History')
          Wrap(
            spacing: 12,
            children: [
              TextButton(
                onPressed: page > 0 ? () => setState(() => page--) : null,
                child: const Text('Previous page'),
              ),
              Text(
                'Page ${page + 1} · totals use the complete entitled snapshot',
              ),
              TextButton(
                onPressed: (page + 1) * 50 < (g.data['activity'] as List).length
                    ? () => setState(() => page++)
                    : null,
                child: const Text('Next page'),
              ),
            ],
          ),
        if (repo.intents.any((i) => i['state'] != 'reconciled')) ...[
          const SizedBox(height: 24),
          const SectionHeading('Saved group work'),
          for (final i in repo.intents.where((i) => i['state'] != 'reconciled'))
            FinancialLine(
              key: ValueKey('shared-intent-${i['id']}'),
              intentTitle(object(jsonDecode(i['payload'] as String)), g),
              intentState(i),
              icon: Icons.cloud_queue,
              color: Palette.peach,
              onTap: () =>
                  SharedFlows(widget.hub).openWork(context, i['id'] as String),
            ),
        ],
      ],
    );
  }
}

class SharedField {
  const SharedField(this.key, this.label, {this.value = '', this.options});
  final String key, label, value;
  final Map<String, String>? options;
}

class _SharedForm extends StatefulWidget {
  const _SharedForm({
    required this.title,
    required this.fields,
    required this.onSave,
    this.onDraft,
    this.preview,
  });
  final String title;
  final List<SharedField> fields;
  final Future<void> Function(Map<String, String>) onSave;
  final Future<void> Function(Map<String, String>)? onDraft;
  final List<String> Function(Map<String, String>)? preview;
  @override
  State<_SharedForm> createState() => _SharedFormState();
}

class _SharedFormState extends State<_SharedForm> {
  late final controls = {
    for (final f in widget.fields)
      f.key: TextEditingController(
        text: f.value.isEmpty && f.options != null
            ? f.options!.keys.first
            : f.value,
      ),
  };
  String? error;
  bool busy = false, review = false, dirty = false;
  List<String> effects = [];
  Future<void> draftWrites = Future.value();
  void retain() {
    setState(() => dirty = true);
    if (widget.onDraft == null) return;
    final frozen = values;
    draftWrites = draftWrites.then((_) => widget.onDraft!(frozen)).catchError((
      Object e,
    ) {
      if (mounted) {
        setState(
          () => error = 'This draft could not be saved. Check available storage and retry.',
        );
      }
    });
  }

  Map<String, String> get values => {
    for (final e in controls.entries) e.key: e.value.text.trim(),
  };
  @override
  void dispose() {
    for (final c in controls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormExitGuard(
    dirty: dirty,
    busy: busy,
    keepDraft: widget.onDraft == null
        ? null
        : () async {
            await draftWrites;
            if (error != null) throw StateError('Draft not saved');
          },
    child: FinancePage(
      title: widget.title,
      child: WorkspaceForm(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkspaceSteps(active: review ? 1 : 0),
            FinanceHeading(
              'FINANCIAL WORKFLOW / ${review ? '02 REVIEW' : '01 DETAILS'}',
              widget.title,
              'Review exact group facts and your own private effects separately.',
            ),
            FinanceColumns(
              main: EditorialSurface(
                padding: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null)
                      FormStatus(
                        title: 'Needs attention',
                        message: error!,
                        tone: NoticeTone.warning,
                      ),
                    if (busy)
                      const FormStatus(
                        title: 'Saving reviewed values\u2026',
                        message: 'Keep this form open while your original request is checked.',
                        busy: true,
                      ),
                    if (review) ...[
                      ReviewNotes(effects),
                      const FinanceNotice(
                        'Review the values below. Group reporting moves no private money. Receipt confirmation is independent from synchronization.',
                      ),
                      for (final f in widget.fields)
                        ReviewRow(
                          f.label,
                          f.options?[values[f.key]] ?? values[f.key] ?? '',
                        ),
                    ] else
                      for (final f in widget.fields)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: f.options == null
                              ? TextField(
                                  key: ValueKey('shared-field-${f.key}'),
                                  controller: controls[f.key],
                                  decoration: InputDecoration(
                                    labelText: f.label,
                                  ),
                                  onChanged: (_) {
                                    retain();
                                  },
                                  maxLength: 2000,
                                )
                              : DropdownButtonFormField<String>(
                                  key: ValueKey('shared-field-${f.key}'),
                                  initialValue: controls[f.key]!.text,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: f.label,
                                  ),
                                  items: [
                                    for (final o in f.options!.entries)
                                      DropdownMenuItem(
                                        value: o.key,
                                        child: Text(
                                          o.value,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) {
                                    controls[f.key]!.text = v!;
                                    retain();
                                  },
                                ),
                        ),
                  ],
                ),
              ),
              aside: EditorialSurface(
                padding: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FinanceNotice(
                      'Your draft stays on this device. Online authority is rechecked when the service accepts the action. Group acceptance never confirms receipt or moves another member’s private money.',
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => Navigator.maybePop(context),
                          child: const Text('Close'),
                        ),
                        if (review)
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setState(() => review = false),
                            child: const Text('Edit'),
                          ),
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  if (!review) {
                                    try {
                                      final calculated =
                                          widget.preview?.call(values) ??
                                          <String>[];
                                      setState(() {
                                        effects = calculated;
                                        review = true;
                                        error = null;
                                      });
                                    } catch (e) {
                                      setState(
                                        () => error = e is LocalRuleException
                                            ? e.message
                                            : e is FormatException
                                            ? e.message
                                            : 'Review exact amounts and participants.',
                                      );
                                    }
                                    return;
                                  }
                                  setState(() {
                                    busy = true;
                                    error = null;
                                  });
                                  try {
                                    await draftWrites;
                                    if (error != null) reject(error!);
                                    await widget.onSave(values);
                                    if (context.mounted) Navigator.pop(context);
                                  } catch (e) {
                                    if (mounted) {
                                      setState(() {
                                        busy = false;
                                        error = e is LocalRuleException
                                            ? e.message
                                            : 'The request could not complete. Your original intent and draft are retained; reconnect and retry.';
                                      });
                                    }
                                  }
                                },
                          child: Text(
                            busy
                                ? 'Saving…'
                                : review
                                ? 'Save reviewed values'
                                : 'Review',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
