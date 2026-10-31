import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../local/finance_domain.dart';
import '../local/local_runtime.dart';
import '../local/local_finance_controller.dart';
import '../local/local_store.dart';
import 'shared_bill_form.dart';
import 'shared_data.dart';
import 'shared_domain.dart';
import 'shared_hub.dart';
import 'shared_pages.dart';
import 'shared_private_form.dart';

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

/// What only a real profile can do, because it needs the encrypted store.
class SharedNativeForms implements SharedPrivateActions {
  SharedNativeForms(this.hub, this.session);
  final SharedHub hub;
  final LocalSession session;

  @override
  Future<void> privateBill(BuildContext context, SharedGroup g, String bill) =>
      privateEffect(context, g, bill, 'bill');

  @override
  Future<void> retainEvidence(
    BuildContext context,
    SharedGroup g,
    String bill,
  ) async {
    final record = session.localFinance.snapshot.current
        .where(
          (r) =>
              r.values['sharedGroup'] == g.id &&
              r.values['sharedKey'] == bill &&
              r.values['sharedMode'] == 'bill',
        )
        .firstOrNull;
    if (record != null) await showKeepRecord(context, hub, g, bill, record);
  }

  @override
  Future<void> privateEffect(
    BuildContext context,
    SharedGroup g,
    String key,
    String mode,
  ) {
    final linked = session.localFinance.snapshot.current.any(
      (r) =>
          r.values['sharedGroup'] == g.id &&
          r.values['sharedKey'] == key &&
          r.values['sharedMode'] == mode,
    );
    return openDemoPage<void>(
      context,
      SharedPrivateForm(
        hub: hub,
        controller: session.localFinance,
        group: g,
        item: key,
        mode: mode,
      ),
      'shared/private',
      title: SharedPrivateForm.titleFor(mode, linked: linked),
    );
  }
}
