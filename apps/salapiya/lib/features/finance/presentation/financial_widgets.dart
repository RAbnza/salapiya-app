import 'package:flutter/material.dart';

import '../../../app/demo_routes.dart';
import '../../../design_system/editorial.dart';
import '../../../design_system/theme.dart';
export '../../../design_system/workspace.dart';

class FinancialEnvironment extends InheritedWidget {
  const FinancialEnvironment({
    super.key,
    required this.production,
    required super.child,
  });
  final bool production;
  static bool isProduction(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<FinancialEnvironment>()
          ?.production ??
      false;
  @override
  bool updateShouldNotify(FinancialEnvironment oldWidget) =>
      production != oldWidget.production;
}

class FinancePage extends StatelessWidget {
  const FinancePage({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => RouteEscape(
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  const BackButton(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Eyebrow(
                          FinancialEnvironment.isProduction(context)
                              ? 'LOCAL ONLY · PRIVATE ON THIS DEVICE'
                              : 'DEMO · SYNTHETIC DATA · RESETS WHEN CLOSED',
                        ),
                        const SizedBox(height: 16),
                        child,
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class FinanceHeading extends StatelessWidget {
  const FinanceHeading(
    this.kicker,
    this.title,
    this.caption, {
    super.key,
    this.actions = const [],
  });
  final String kicker, title, caption;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: LayoutBuilder(
      builder: (context, b) {
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 6),
            Text(
              caption,
              style: TextStyle(color: CraftTheme.of(context).secondary),
            ),
          ],
        );
        final commands = Wrap(spacing: 8, runSpacing: 8, children: actions);
        if (b.maxWidth > 1000 &&
            actions.length <= 3 &&
            MediaQuery.textScalerOf(context).scale(14) < 20) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              const SizedBox(width: 24),
              commands,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading,
            if (actions.isNotEmpty) ...[const SizedBox(height: 16), commands],
          ],
        );
      },
    ),
  );
}

class FinanceColumns extends StatelessWidget {
  const FinanceColumns({
    super.key,
    required this.main,
    required this.aside,
    this.ratio = 2,
  });
  final Widget main, aside;
  final int ratio;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, b) {
      if (b.maxWidth < 850 || MediaQuery.textScalerOf(context).scale(14) > 21) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [main, const SizedBox(height: 24), aside],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: ratio, child: main),
          const SizedBox(width: 28),
          Expanded(child: aside),
        ],
      );
    },
  );
}

class FinanceNotice extends StatelessWidget {
  const FinanceNotice(this.text, {super.key, this.warning = false});
  final String text;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: warning
          ? CraftTheme.of(context).warmSurface
          : CraftTheme.of(context).surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: CraftTheme.of(context).divider),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          warning ? Icons.info_outline : Icons.info_outline,
          size: 20,
          color: warning
              ? CraftTheme.of(context).warm
              : CraftTheme.of(context).primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: CraftTheme.of(context).secondary,
            ),
          ),
        ),
      ],
    ),
  );
}
