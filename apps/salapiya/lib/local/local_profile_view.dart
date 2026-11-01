import 'dart:async';

import '../connected/connection_view.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/shell.dart';
import '../design_system/craft.dart';
import '../design_system/theme.dart';
import '../design_system/welcome_frame.dart';
import '../features/finance/presentation/financial_widgets.dart';
import '../finance/bounded_file_read.dart';
import '../gallery/settings.dart';
import 'finance_domain.dart';
import 'local_profiles.dart';
import 'local_runtime.dart';

class LocalBootstrap extends StatefulWidget {
  const LocalBootstrap({super.key, required this.settings, this.runtime});
  final GallerySettings settings;
  final LocalRuntime? runtime;
  @override
  State<LocalBootstrap> createState() => _LocalBootstrapState();
}

class _LocalBootstrapState extends State<LocalBootstrap>
    with WidgetsBindingObserver {
  LocalRuntime? runtime;
  bool loading = true;
  String? failure;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(start());
  }

  Future<void> start() async {
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final next = widget.runtime ?? await LocalRuntime.open(widget.settings);
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
      if (mounted) {
        setState(() {
          loading = false;
          failure = e is LocalRuleException ? e.message : 'The protected local profile could not be opened. Existing files have been preserved. Check OS credentials and available storage, then retry.';
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
    if (loading) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandMark(size: 80),
                SizedBox(height: 24),
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Opening your private space…'),
              ],
            ),
          ),
        ),
      );
    }
    if (failure != null) {
      return FinancePage(
        title: 'Your private space',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FinanceHeading(
              'SALAPIYA / RECOVERY',
              'Your data stays yours.',
              'Startup stopped safely; no existing profile was reset.',
            ),
            FinanceNotice(failure!, warning: true),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: start,
              child: const Text('Retry opening profile'),
            ),
          ],
        ),
      );
    }
    return ListenableBuilder(
      listenable: runtime!,
      builder: (context, _) => runtime!.session == null
          ? LocalWelcome(runtime: runtime!)
          : SalapiyaShell(
              key: ValueKey(runtime!.session),
              settings: widget.settings,
              session: runtime!.session,
            ),
    );
  }
}

class LocalWelcome extends StatefulWidget {
  const LocalWelcome({super.key, required this.runtime});
  final LocalRuntime runtime;
  @override
  State<LocalWelcome> createState() => _LocalWelcomeState();
}

class _LocalWelcomeState extends State<LocalWelcome> {
  @override
  Widget build(BuildContext context) => WelcomeFrame(
    back: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your money, on your terms.',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 12),
        Text(
          'Welcome to a little more clarity. Start privately on this device, or bring your existing space with you.',
          style: TextStyle(
            color: CraftTheme.of(context).secondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),
        WorkspacePanel(
          title: 'Start with your own space',
          caption: 'No internet, email or Google account needed.',
          child: FilledButton.icon(
            onPressed: () => openDemoPage<void>(
              context,
              LocalProfileSetup(runtime: widget.runtime),
              'profile/create',
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create a local offline profile'),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => openDemoPage<void>(
            context,
            ConnectionPage(runtime: widget.runtime),
            'profile/connection',
          ),
          icon: const Icon(Icons.login, size: 18),
          label: const Text('Continue with Google'),
        ),
        const SizedBox(height: 8),
        Text(
          'Connect privately or retrieve your existing profile.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: () => openDemoPage<void>(
            context,
            LocalRecoveryView(runtime: widget.runtime),
            'profile/recovery',
          ),
          icon: const Icon(Icons.restore, size: 18),
          label: const Text('Restore from backup'),
        ),
        const SizedBox(height: 28),
        const WorkspaceHelp(
          title: 'Your profile and your privacy',
          text: 'One active profile per installation. Your financial accounts live inside this private profile. Google connection is optional and requires your confirmation before private records are uploaded. Keep a portable backup and its recovery secret separately.',
        ),
      ],
    ),
  );
}

class LocalProfileSetup extends StatefulWidget {
  const LocalProfileSetup({super.key, required this.runtime});
  final LocalRuntime runtime;
  @override
  State<LocalProfileSetup> createState() => _LocalProfileSetupState();
}

class _LocalProfileSetupState extends State<LocalProfileSetup> {
  final name = TextEditingController();
  ThemeMode mode = ThemeMode.system;
  bool busy = false, allowPop = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    if (busy) return;
    if (name.text.isNotEmpty || mode != ThemeMode.system) {
      if (!await confirmDiscard(context)) return;
    }
    if (!mounted) return;
    setState(() => allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> create() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.runtime.create(name.text, mode);
      if (mounted) {
        setState(() {
          allowPop = true;
          busy = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e is LocalRuleException ? e.message : 'Profile creation could not finish. Your initialized files are retained. Try opening the app again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) leave();
    },
    child: WelcomeFrame(
      step: 'Your profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Make yourself at home.',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Just a name and a preference. Everything else can come later.',
          ),
          const SizedBox(height: 28),
          TextField(
            controller: name,
            autofocus: true,
            enabled: !busy,
            maxLength: 200,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Display name',
              hintText: 'What should we call you?',
              errorText: error,
            ),
            onSubmitted: (_) {
              if (!busy) create();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ThemeMode>(
            initialValue: mode,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Appearance'),
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('Follow device settings'),
              ),
              DropdownMenuItem(
                value: ThemeMode.light,
                child: Text('Porcelain - light'),
              ),
              DropdownMenuItem(
                value: ThemeMode.dark,
                child: Text('Midnight - dark'),
              ),
            ],
            onChanged: busy ? null : (v) => setState(() => mode = v!),
          ),
          const SizedBox(height: 24),
          const FinanceNotice(
            'PHP - Asia/Manila. Your profile is encrypted on this device and works offline. No financial account is created yet.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: busy ? null : create,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward, size: 18),
            label: Text(
              busy ? 'Creating your space...' : 'Create local profile',
            ),
          ),
          TextButton(
            onPressed: busy ? null : leave,
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}

void showUpcoming(BuildContext context, String workflow) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(workflow),
    content: const Text(
      'This workflow is planned for a later milestone. Your local profile remains available offline.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    ],
  ),
);

class UpcomingView extends StatelessWidget {
  const UpcomingView(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FinanceHeading(
        'SALAPIYA / COMING LATER',
        title,
        'A little more room for what comes next.',
      ),
      const ValueBlock(
        'PLANNED WORKFLOW',
        'Your space is ready to grow.',
        'This feature will become available in a later milestone. Your everyday Money records remain available offline.',
        color: Palette.lilac,
      ),
    ],
  );
}

class LocalRecoveryView extends StatelessWidget {
  const LocalRecoveryView({super.key, required this.runtime});
  final LocalRuntime runtime;
  @override
  Widget build(BuildContext context) => WelcomeFrame(
    step: 'Restore',
    child: LocalRecoveryBody(runtime: runtime),
  );
}

/// Restoring on a new device, from the welcome screen (Chat 15). A profile in
/// use has Backup & recovery instead.
class LocalRecoveryBody extends StatefulWidget {
  const LocalRecoveryBody({super.key, required this.runtime});
  final LocalRuntime runtime;
  @override
  State<LocalRecoveryBody> createState() => _LocalRecoveryBodyState();
}

class _LocalRecoveryBodyState extends State<LocalRecoveryBody> {
  final secret = TextEditingController();
  bool busy = false;
  String? message;
  Map<String, dynamic>? reviewed;
  @override
  void dispose() {
    secret.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() work) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is LocalRuleException ? e.message : 'Recovery could not complete. Check the file and recovery secret. Existing data has been preserved.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FinanceHeading(
          'YOUR SAFETY NET',
          'Keep a way back.',
          'Use your encrypted archive and its separate recovery secret. Review the contents before activating a restored profile.',
        ),
        const WorkspaceHelp(
          title: 'What your backup includes',
          text: 'Archives include financial evidence, Life records and history, original pending intents, document metadata, visibility preferences and protected drafts. File bytes, notification consent and OS schedule IDs are excluded. Keep original files separately; destination reminders start off.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: secret,
          maxLines: 2,
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Recovery secret',
            helperText: 'Keep this separately from your archive. It cannot be recovered from Salapiya.',
          ),
          onChanged: (_) => setState(() => reviewed = null),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () => run(() async {
                  final file = await FilePicker.pickFile();
                  if (file == null) return;
                  final bundle = await LocalBackup.unseal(
                    await readBoundedFinancialFile(
                      file,
                      LocalBackup.maxBytes + 128,
                    ),
                    secret.text,
                  );
                  if (mounted) setState(() => reviewed = bundle);
                }),
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Choose and inspect backup'),
        ),
        if (reviewed != null) ...[
          const SizedBox(height: 20),
          ReviewRow('Archive', reviewed!['name'] as String, emphasis: true),
          ReviewRow('Created', reviewed!['createdUtc'] as String),
          ReviewRow(
            'Financial history',
            '${(reviewed!['commands'] as List).length} committed commands',
          ),
          ReviewRow(
            'Protected drafts',
            '${(reviewed!['drafts'] as List).length}',
          ),
          ReviewRow(
            'Life history',
            '${((reviewed!['life'] as Map?)?['revisions'] as List? ?? const []).length} revisions / ${((reviewed!['life'] as Map?)?['intents'] as List? ?? const []).length} original intents',
          ),
          FormStatus(
            title: 'Recovery coverage',
            tone: NoticeTone.warning,
            message:
                '${[2, 3].contains(reviewed!['format']) ? 'Connected recovery requires current Google verification.' : 'Local-only archive.'} Attachment byte objects included: 0. Metadata is not proof that original bytes were recovered.',
          ),
          FormEvidence(
            children: [
              SelectableText(
                'Original profile: ${reviewed!['owner']}\nArchive format: ${reviewed!['format']}',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: FilledButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      final store = await widget.runtime.profiles.restore(
                        reviewed!,
                      );
                      await widget.runtime.activate(store);
                      if (context.mounted) Navigator.maybePop(context);
                    }),
              child: const Text('Restore reviewed local profile'),
            ),
          ),
        ],
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: FormStatus(
              title: 'Backup / recovery status',
              message: message!,
            ),
          ),
      ],
    );
  }
}
