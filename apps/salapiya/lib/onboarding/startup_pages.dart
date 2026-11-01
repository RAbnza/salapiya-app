import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/craft.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../design_system/welcome_frame.dart';
import 'onboarding_data.dart';

/// "Is my data all right?" Shown while the profile opens and its records are
/// checked. Nothing here can claim more than that: a slow start only says
/// closing the app is safe, which is true because every stage of opening
/// resumes or rolls back.
class OpeningScreen extends StatefulWidget {
  const OpeningScreen({super.key});
  static const slowAfter = Duration(seconds: 5);
  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen> {
  Timer? timer;
  bool slow = false;
  @override
  void initState() {
    super.initState();
    timer = Timer(OpeningScreen.slowAfter, () => setState(() => slow = true));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Space.popoverMaxWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: Space.xxxl * 2),
                  const SizedBox(height: Space.xl),
                  Text(
                    'Opening Salapiya',
                    textAlign: TextAlign.center,
                    style: text.titleLarge,
                  ),
                  const SizedBox(height: Space.captionGap),
                  Text(
                    'Checking what’s on this device',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: c.secondary),
                  ),
                  const SizedBox(height: Space.xl),
                  const SizedBox.square(
                    dimension: Space.xl,
                    child: CircularProgressIndicator(strokeWidth: Space.xxs),
                  ),
                  if (slow) ...[
                    const SizedBox(height: Space.xl),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        'This can take longer after an update. Nothing is '
                        'lost if you close Salapiya.',
                        textAlign: TextAlign.center,
                        style: text.bodySmall?.copyWith(color: c.secondary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "What went wrong, what's safe, and what can I do?" Try again is the only
/// action: nothing else is safe here. A restore could overwrite the only key
/// to the profile if the device's credential store comes back.
class StartupFailurePage extends StatelessWidget {
  const StartupFailurePage({
    super.key,
    required this.problem,
    required this.onRetry,
    this.message,
    this.folder,
  });
  final StartupProblem problem;
  final VoidCallback onRetry;

  /// The rule's own words, when there are any. Never an exception's text,
  /// which could quote a key.
  final String? message;
  final String? folder;
  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    final words = startupWords(problem, message: message, desktop: desktop);
    final text = Theme.of(context).textTheme;
    final c = CraftTheme.of(context);
    Widget part(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.titleSmall),
          const SizedBox(height: Space.captionGap),
          Text(value, style: text.bodyMedium?.copyWith(color: c.secondary)),
        ],
      ),
    );
    final details = [
      if (message != null) Text(message!, style: text.bodySmall),
      if (desktop && folder != null) ...[
        if (message != null) const SizedBox(height: Space.xs),
        SelectableText(
          'Your profile’s folder: $folder',
          style: text.bodySmall,
        ),
      ],
    ];
    return WelcomeFrame(
      back: false,
      title: words.title,
      child: Semantics(
        liveRegion: true,
        child: SurfaceCard(
          key: const ValueKey('startup-failure'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              part('What happened', words.happened),
              part('What’s safe', words.safe),
              part('What you can do', words.canDo),
              const SizedBox(height: Space.xs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppButton(
                  'Try again',
                  key: const ValueKey('startup-retry'),
                  onPressed: onRetry,
                ),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: Space.xs),
                FormMoreDetails(label: 'Show details', children: details),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
