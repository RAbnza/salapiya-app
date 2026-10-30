import 'package:flutter/material.dart';

import '../../../design_system/kit/kit.dart' show QuickAction;
import '../../../prototype/scenarios.dart';
import '../../../local/local_finance_controller.dart';
import '../../../finance/debt_demo.dart';
import '../../../finance/debt_screen.dart';

class DebtsScreen extends StatelessWidget {
  const DebtsScreen({
    super.key,
    required this.session,
    this.initial,
    this.actions = const [],
  });
  final PrototypeSession session;

  /// The tab to open on, by its label.
  final String? initial;
  final List<QuickAction> actions;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final c = session.finance;
      if (c is LocalFinancialController) {
        return NativeDebtsScreen(
          controller: c,
          session: session,
          initial: initial,
          actions: actions,
        );
      }
      return DebtsDashboard(
        listenable: session,
        source: (context) => demoDebtsSource(context, session),
        initial: initial,
        actions: actions,
      );
    },
  );
}
