import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app/demo_routes.dart';
import '../app/shell.dart';
import '../gallery/settings.dart';
import '../onboarding/google_page.dart';
import '../onboarding/greeting_page.dart';
import '../onboarding/onboarding_actions.dart';
import '../onboarding/onboarding_data.dart';
import '../onboarding/restore_page.dart';
import '../onboarding/setup_page.dart';
import '../onboarding/startup_pages.dart';
import '../onboarding/welcome_page.dart';
import 'finance_domain.dart';
import 'local_profiles.dart';
import 'local_runtime.dart';

/// Opens a real runtime. Tests pass their own, so a failed start can be shown.
typedef RuntimeOpener = Future<LocalRuntime> Function(GallerySettings settings);

/// What can be read about the installation after a failed start.
typedef StartupReader = Future<StartupFacts> Function();

Future<StartupFacts> _readStartup() async {
  final support = await getApplicationSupportDirectory();
  return readStartupFacts(
    LocalProfiles(
      Directory(p.join(support.path, 'local-v1')),
      const OsProfileVault(),
    ),
  );
}

class LocalBootstrap extends StatefulWidget {
  const LocalBootstrap({
    super.key,
    required this.settings,
    this.runtime,
    this.opener = LocalRuntime.open,
    this.reader = _readStartup,
  });
  final GallerySettings settings;
  final LocalRuntime? runtime;
  final RuntimeOpener opener;
  final StartupReader reader;
  @override
  State<LocalBootstrap> createState() => _LocalBootstrapState();
}

class _LocalBootstrapState extends State<LocalBootstrap>
    with WidgetsBindingObserver {
  LocalRuntime? runtime;
  bool loading = true;
  bool failed = false;

  /// Past the greeting, or a profile has been open since the app started, so
  /// someone who has just removed one goes straight to Welcome.
  bool greeted = false;
  String? failure;
  StartupFacts facts = const StartupFacts();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(start());
  }

  Future<void> start() async {
    setState(() {
      loading = true;
      failed = false;
      failure = null;
    });
    try {
      final next = widget.runtime ?? await widget.opener(widget.settings);
      if (!mounted) {
        if (widget.runtime == null) {
          await next.close();
          next.dispose();
        }
        return;
      }
      setState(() {
        runtime = next;
        loading = false;
      });
    } catch (e) {
      // Only the rules' own words: an exception's text could quote a key.
      final why = e is LocalRuleException ? e.message : null;
      StartupFacts found;
      try {
        found = await widget.reader();
      } catch (_) {
        found = const StartupFacts();
      }
      if (mounted) {
        setState(() {
          loading = false;
          failed = true;
          failure = why;
          facts = found;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        runtime?.connected.connected == true) {
      unawaited(runtime!.connected.syncNow());
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(runtime?.flushPreferences());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final r = runtime;
    if (r != null && widget.runtime == null) {
      unawaited(r.close().whenComplete(r.dispose));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const OpeningScreen();
    if (failed) {
      return StartupFailurePage(
        problem: startupProblemOf(failure, phase: facts.phase),
        message: failure,
        folder: facts.folder,
        onRetry: start,
      );
    }
    final actions = LocalOnboardingActions(runtime!);
    return ListenableBuilder(
      listenable: runtime!,
      builder: (context, _) {
        final session = runtime!.session;
        if (session != null) {
          greeted = true;
          return SalapiyaShell(
            key: ValueKey(session),
            settings: widget.settings,
            session: session,
          );
        }
        if (!greeted) {
          return GreetingPage(
            actions: actions,
            onStart: () => setState(() => greeted = true),
          );
        }
        return WelcomePage(
          actions: actions,
          onStart: () => openDemoPage<void>(
            context,
            ProfileSetupPage(actions: actions),
            'profile/create',
          ),
          onGoogle: () => openDemoPage<void>(
            context,
            GooglePage(actions: actions),
            'profile/connection',
          ),
          onRestore: () => openDemoPage<void>(
            context,
            RestorePage(actions: actions),
            'profile/recovery',
          ),
        );
      },
    );
  }
}
