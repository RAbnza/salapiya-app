import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../design_system/welcome_frame.dart';
import '../local/finance_domain.dart' show LocalRuleException;
import 'onboarding_actions.dart';
import 'onboarding_data.dart';
import 'records_map.dart';

/// Refusals that belong on Display name. Anything else isn't about the name.
const setupNameErrors = ['Enter a display name'];

/// "What do you need from me, and what can wait?"
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key, required this.actions, this.onDone});
  final OnboardingActions actions;

  /// Finished. By default every first-run page closes.
  final VoidCallback? onDone;
  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  OnboardingActions get a => widget.actions;
  final name = TextEditingController();
  final nameFocus = FocusNode();

  /// What was showing when this page opened, to go back to on leaving. A
  /// profile that was just removed may have left its own theme on.
  late final ThemeMode started = a.theme;
  late ThemeMode theme = started;
  bool busy = false, allowPop = false;

  /// A first try got part-way, so the name is saved and the next try carries
  /// on from there. It can't change now, and creating again would be refused.
  bool resuming = false;
  String? nameError, error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) nameFocus.requestFocus();
      recheck();
    });
  }

  @override
  void dispose() {
    name.dispose();
    nameFocus.dispose();
    super.dispose();
  }

  /// Picks up a first run that stopped part-way earlier in this session.
  Future<void> recheck() async {
    final DeviceStart start;
    try {
      start = await a.deviceStart();
    } catch (_) {
      return;
    }
    if (!mounted || !start.unfinished) return;
    setState(() {
      resuming = true;
      name.text = start.pendingName ?? name.text;
    });
  }

  Future<void> leave() async {
    if (busy) return;
    // Part-way through, nothing is lost by leaving: it's saved, and Start
    // carries on from it.
    if (!resuming && (name.text.isNotEmpty || theme != started)) {
      final yes = await showAdaptiveModal<bool>(
        context,
        title: 'Discard your changes?',
        body: const Text('Your profile hasn’t been created yet.'),
        primary: const ModalAction(
          'Discard changes',
          value: true,
          destructive: true,
        ),
        secondary: const ModalAction.cancel(label: 'Keep editing'),
      );
      if (yes != true) return;
    }
    if (!mounted) return;
    if (a.theme != started) a.showTheme(started);
    setState(() => allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.maybePop(context);
    });
  }

  Future<void> create() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      nameError = null;
    });
    try {
      if (resuming) {
        await a.resume();
      } else {
        await a.create(name.text, theme);
      }
      if (!mounted) return;
      setState(() {
        allowPop = true;
        busy = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final close = widget.onDone;
        if (close != null) {
          close();
        } else {
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
      });
    } catch (e) {
      final why = e is LocalRuleException
          ? e.message
          : 'Your profile isn’t set up yet. Nothing was lost. Try again.';
      await recheck();
      if (!mounted) return;
      setState(() {
        busy = false;
        if (setupNameErrors.any(why.contains)) {
          nameError = why;
        } else {
          error = why;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fields = <Widget>[
      HelpTextField(
        key: const ValueKey('setup-name'),
        label: 'Display name',
        helper: resuming
            ? 'Saved already. You can change it later in Profile.'
            : 'What should Salapiya call you?',
        controller: name,
        focusNode: nameFocus,
        readOnly: resuming,
        enabled: !busy,
        errorText: nameError,
        keyboardType: TextInputType.name,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() => nameError = null),
        onSubmitted: (_) => create(),
      ),
      // Once a first try has saved it, the theme can't change here either.
      if (!resuming) ...[
        SizedBox(height: CompactForm.fieldGap(context)),
        Text('Theme', style: text.labelMedium),
        SizedBox(height: CompactForm.innerGap(context) + Space.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MiniSegmented<ThemeMode>(
            key: const ValueKey('setup-theme'),
            label: 'Theme',
            options: const [
              (ThemeMode.system, 'System'),
              (ThemeMode.light, 'Light'),
              (ThemeMode.dark, 'Dark'),
            ],
            selected: theme,
            onSelected: (mode) {
              if (busy) return;
              setState(() => theme = mode);
              a.showTheme(mode);
            },
          ),
        ),
      ],
      SizedBox(height: CompactForm.groupGap(context)),
      const InlineNotice(
        'Amounts are in pesos and dates follow Manila time. Your '
        'profile is encrypted on this device and works offline. No '
        'accounts are added yet.',
        tone: NoticeTone.neutral,
      ),
      if (error != null) ...[
        SizedBox(height: CompactForm.fieldGap(context)),
        InlineNotice(error!, tone: NoticeTone.error, live: true),
      ],
    ];
    final buttons = Wrap(
      alignment: WrapAlignment.end,
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        AppButton.tertiary(
          'Cancel',
          key: const ValueKey('setup-cancel'),
          onPressed: busy ? null : leave,
        ),
        AppButton(
          resuming ? 'Try again' : 'Create profile',
          key: const ValueKey('setup-create'),
          icon: Icons.arrow_forward,
          busy: busy,
          onPressed: busy ? null : create,
        ),
      ],
    );
    final form = OverviewCard(
      key: const ValueKey('setup-form'),
      title: 'Your profile',
      fill: true,
      child: CompactForm(
        // Beside a taller map the card's height arrives only as a minimum;
        // the buttons take the bottom of it.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: fields,
            ),
            Padding(
              padding: EdgeInsets.only(top: CompactForm.groupGap(context)),
              child: buttons,
            ),
          ],
        ),
      ),
    );
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: WelcomeFrame(
        title: 'Create your profile',
        caption: 'A name and a theme. Accounts, budgets and Google can wait.',
        aside: recordsCard(RecordsView.local),
        lead: const RecordsMap(view: RecordsView.local, slim: true),
        child: form,
      ),
    );
  }
}
