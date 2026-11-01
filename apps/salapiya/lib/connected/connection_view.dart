import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../design_system/welcome_frame.dart';
import '../features/finance/presentation/financial_widgets.dart';
import '../local/local_runtime.dart';
import '../profile/profile_page.dart';
import '../shared/shared_hub.dart';
import 'connected_runtime.dart';

/// The profile's Connection tab, wherever a link to it comes from: the
/// shell's own page when there is one.
void openConnection(BuildContext context, LocalRuntime runtime) {
  final open = SharedScope.maybeOf(context)?.openConnection;
  if (open != null) {
    open();
    return;
  }
  openDemoPage<void>(context, ConnectionPage(runtime: runtime), 'profile');
}

class ConnectionPage extends StatelessWidget {
  const ConnectionPage({super.key, required this.runtime});
  final LocalRuntime runtime;
  @override
  Widget build(BuildContext context) {
    final session = runtime.session;
    return session == null
        ? WelcomeFrame(
            step: 'Google connection',
            child: ConnectionBody(runtime: runtime),
          )
        : ProfilePage(
            session: session,
            settings: runtime.settings,
            tab: ValueNotifier('Connection'),
          );
  }
}

class ConnectionBody extends StatefulWidget {
  const ConnectionBody({super.key, required this.runtime});
  final LocalRuntime runtime;
  @override
  State<ConnectionBody> createState() => _ConnectionBodyState();
}

class _ConnectionBodyState extends State<ConnectionBody> {
  ConnectedRuntime get c => widget.runtime.connected;
  Future<void> confirm() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Enable private synchronization?'),
        content: Text(
          'Selected Google identity: ${c.identity}\n\n'
          'Connecting uploads your private Money and Life records, financial evidence, Career details and document metadata to Salapiya’s configured Supabase and PowerSync services. Document bytes remain on the device. '
          'Google supplies identity. Drafts and device preferences stay on this device. '
          'Authorized service administrators may access cloud data; this is not end-to-end encryption. '
          'Existing cloud history is downloaded before complete totals are shown.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm connection'),
          ),
        ],
      ),
    );
    if (yes == true) await c.confirmConnection();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final signed = c.flow?.client.auth.currentUser != null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FinanceHeading(
            'PRIVATE CONNECTION',
            'Your money, across devices.',
            'Google is optional. Local records remain encrypted and available through connection failures.',
          ),
          ValueBlock(
            'CONNECTION',
            c.label,
            '${c.identity}\nFinancial: ${c.pendingCount} waiting · ${c.reviewCount} for review. Life: ${c.lifePendingCount} waiting · ${c.lifeReviewCount} for review (open Life).',
          ),
          const SizedBox(height: 20),
          if (!c.configured)
            const FinanceNotice(
              'This build supports local use. Google requires the existing development service configuration.',
              warning: true,
            ),
          if (c.error != null)
            Semantics(
              liveRegion: true,
              child: FinanceNotice(c.error!, warning: true),
            ),
          if (c.flow != null &&
              ![
                'ready',
                'google_code_exchange_verified',
              ].contains(c.flow!.outcome))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(switch (c.flow!.outcome) {
                'waiting_for_google' || 'interrupted_attempt_restored' => 'Complete the account selection in your system browser, or cancel sign-in.',
                'wrong_account_local_data_preserved' => 'That is a different Google identity. Reconnect with the identity bound to this profile.',
                'cancelled_local_data_preserved' || 'provider_cancelled' =>
                  'Sign-in cancelled. Your local records are unchanged.',
                'late_callback_ignored' => 'The cancelled sign-in was ignored. Start a new attempt when ready.',
                _ => 'Sign-in could not finish. Your local records are preserved. Try again.',
              }),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (c.flow?.pending == true)
                OutlinedButton(
                  onPressed: c.busy ? null : () => c.flow!.cancel(),
                  child: const Text('Cancel sign-in'),
                )
              else
                FilledButton.icon(
                  onPressed: c.busy || !c.configured ? null : c.signIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Select Google account'),
                ),
              if (signed)
                OutlinedButton(
                  onPressed: c.busy ? null : c.lookup,
                  child: const Text('Review selected Google account'),
                ),
              if (signed)
                FilledButton(
                  onPressed: c.busy ? null : confirm,
                  child: const Text('Review connection'),
                ),
              TextButton(
                onPressed: c.busy ? null : c.cancelConnection,
                child: const Text('Cancel connection'),
              ),
            ],
          ),
          if (c.busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: LinearProgressIndicator(),
            ),
        ],
      );
    },
  );
}
