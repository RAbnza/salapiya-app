import 'package:flutter/material.dart';

import '../design_system/kit/section_page.dart';
import '../features/finance/presentation/financial_widgets.dart';

export '../design_system/kit/section_page.dart' show RouteEscape;

/// A single SDK stack for detail/task/utility routes. Primary tabs never push.
/// Await removal before unlocking callers and restoring their focus.
/// The page title travels as the route arguments for the shell's breadcrumb.
Future<T?> openDemoPage<T>(
  BuildContext context,
  Widget page,
  String name, {
  String? title,
}) async {
  if (!(ModalRoute.of(context)?.isCurrent ?? true)) return null;
  final origin = FocusManager.instance.primaryFocus;
  final reduced = MediaQuery.disableAnimationsOf(context);
  final route = PageRouteBuilder<T>(
    settings: RouteSettings(
      name: name,
      arguments:
          title ??
          switch (page) {
            FinancePage(:final title) ||
            DemoPage(:final title) ||
            SectionPage(:final title) => title,
            _ => null,
          },
    ),
    transitionDuration: reduced
        ? Duration.zero
        : const Duration(milliseconds: 160),
    reverseTransitionDuration: reduced
        ? Duration.zero
        : const Duration(milliseconds: 120),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
  final result = await Navigator.of(context).push<T>(route);
  await route.completed;
  if (origin?.context != null) origin!.requestFocus();
  return result;
}

class DemoPage extends StatelessWidget {
  const DemoPage({super.key, required this.title, required this.child});
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
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'DEMO · synthetic data · resets when closed',
                        ),
                        const SizedBox(height: 24),
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
