import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import 'greeting_preview.dart';
import 'onboarding_actions.dart';

/// "What is this, and how do I begin?" The first thing someone sees with no
/// profile open. It holds nothing they'd need to come back to, so with work
/// in progress it steps aside for Welcome, which has something to say.
class GreetingPage extends StatefulWidget {
  const GreetingPage({super.key, required this.actions, required this.onStart});
  final OnboardingActions actions;
  final VoidCallback onStart;
  @override
  State<GreetingPage> createState() => _GreetingPageState();
}

class _GreetingPageState extends State<GreetingPage> {
  OnboardingActions get a => widget.actions;
  bool gone = false;
  @override
  void initState() {
    super.initState();
    a.changes.addListener(check);
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  @override
  void dispose() {
    a.changes.removeListener(check);
    super.dispose();
  }

  Future<void> load() async {
    check();
    final start = await a.deviceStart();
    if (mounted && start.unfinished) leave();
  }

  /// A sign-in carried over a restart, so Welcome's Continue is what's next.
  void check() {
    final f = a.facts();
    if (f.signingIn || f.signedIn || f.busy) leave();
  }

  void leave() {
    if (gone) return;
    gone = true;
    // Nothing on this screen redraws by itself, so ask for the frame.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) widget.onStart();
      })
      ..ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final desktop = isDesktop(context);
    final large = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final logo = Align(
      alignment: AlignmentDirectional.centerStart,
      child: Image.asset(
        'assets/branding/display/salapiya_horizontal_on_${c.dark ? 'dark' : 'light'}.png',
        height: Space.xxxl,
        semanticLabel: 'Salapiya',
      ),
    );
    Widget headline(TextStyle? style, {bool center = false}) => Semantics(
      header: true,
      child: Text(
        'Keep track of your money and plans in one place.',
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: style,
      ),
    );
    const sections = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          Icons.account_balance_wallet_outlined,
          'Money',
          'Accounts, spending and budgets',
        ),
        _Section(
          Icons.receipt_long_outlined,
          'Debts',
          'What you owe and what’s next',
        ),
        _Section(
          Icons.group_outlined,
          'Shared Expenses',
          'Who owes whom in a group',
        ),
        _Section(
          Icons.event_note_outlined,
          'Life',
          'Calendar, tasks and reminders',
        ),
      ],
    );
    final start = AppButton(
      'Get started',
      key: const ValueKey('greeting-start'),
      icon: Icons.arrow_forward,
      expand: !desktop,
      onPressed: leave,
    );
    final note = Text(
      'Salapiya records what happens elsewhere. It never moves money.',
      style: text.bodySmall?.copyWith(color: c.secondary),
    );
    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final width = WidthClass.of(context);
            final gutter = Space.pageGutter(width);
            // Beside the preview once the window can hold both; large text
            // takes the wider layout's room, as it does everywhere (§2).
            if (desktop && box.maxWidth >= Space.xxxl * 21 && !large) {
              return Padding(
                padding: const EdgeInsets.all(Space.xxl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: Space.contentMaxWidth,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                logo,
                                const SizedBox(height: Space.xl),
                                headline(text.displayMedium),
                                const SizedBox(height: Space.xl),
                                sections,
                                const SizedBox(height: Space.xl),
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: start,
                                ),
                                const SizedBox(height: Space.md),
                                note,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.xxxl),
                        const Expanded(
                          flex: 7,
                          child: SingleChildScrollView(
                            physics: NeverScrollableScrollPhysics(),
                            child: GreetingPreview(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            // A phone keeps it simple: who this is, what it does, one button.
            // Only a screen or text size that can't hold it scrolls, and the
            // button stays in reach either way.
            return Padding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: Space.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Image.asset(
                              'assets/branding/display/salapiya_vertical_on_${c.dark ? 'dark' : 'light'}.png',
                              height: Space.xxxl * 3,
                              semanticLabel: 'Salapiya',
                            ),
                            const SizedBox(height: Space.lg),
                            headline(
                              desktop ? text.displaySmall : text.headlineSmall,
                              center: true,
                            ),
                            const SizedBox(height: Space.lg),
                            sections,
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  Align(child: start),
                  const SizedBox(height: Space.sm),
                  Align(
                    child: Text(
                      'It never moves money.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: c.secondary),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One thing Salapiya keeps track of.
class _Section extends StatelessWidget {
  const _Section(this.icon, this.title, this.line);
  final IconData icon;
  final String title, line;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          IconBadge(icon),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                Text(line, style: text.bodySmall?.copyWith(color: c.secondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
