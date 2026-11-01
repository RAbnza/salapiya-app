import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../prototype/scenarios.dart';
import 'device_reminders.dart' show reminderModules;
import 'life_data.dart';
import 'life_forms.dart' show timezoneOptions;
import 'life_hub.dart';
import 'native_notifications.dart';
import 'reminder_data.dart';
import 'reminder_page.dart';

/// Reminders: what will remind me, when, and how do I change that?
class LifeRemindersTab extends StatefulWidget {
  const LifeRemindersTab({
    super.key,
    required this.source,
    required this.hub,
  });
  final LifeSource source;
  final LifeHub hub;
  @override
  State<LifeRemindersTab> createState() => _LifeRemindersTabState();
}

class _LifeRemindersTabState extends State<LifeRemindersTab> {
  /// Beside two cards: more would leave a gap under them, so the rest are a
  /// tap away.
  static const shown = 8;
  String? problem, quietProblem;
  String? note;
  late Future<List<ReminderLog>> log = load();

  LifeSource get source => widget.source;
  LifeReminders get r => source.reminders!;

  Future<List<ReminderLog>> load() => r.log();

  Future<void> run(Future<void> Function() work) async {
    setState(() {
      problem = quietProblem = note = null;
    });
    try {
      await work();
    } on FormatException catch (e) {
      if (mounted) setState(() => problem = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => problem = 'That didn’t work. Your records are fine.');
      }
    }
    if (mounted) {
      setState(() {
        log = load();
      });
    }
  }

  Future<void> turnOff() async {
    final set = setReminders(r.rows);
    final yes = await showAppDialog<bool>(
      context,
      title: 'Turn off reminders on this device?',
      body: Text(
        '${set == 0 ? 'Nothing is' : set == 1 ? '1 reminder is' : '$set reminders are'} set here${set == 0 ? ', so nothing is cancelled' : ', and will be cancelled'}. Your records and calendar don’t change, and your other devices keep theirs.',
      ),
      primary: const ModalAction('Turn off', value: true),
    );
    if (yes == true) await run(() => r.configure({'enabled': false}));
  }

  Future<void> module(String name, bool value) async {
    final set = setReminders([
      for (final row in r.rows)
        if (row.item.kind == name) row,
    ]);
    if (!value && set > 0) {
      final yes = await showAppDialog<bool>(
        context,
        title: 'Stop reminders for ${lifeModuleName(name).toLowerCase()}?',
        body: Text(
          '${set == 1 ? '1 reminder' : '$set reminders'} on this device will be cancelled. They stay on your calendar.',
        ),
        primary: const ModalAction('Stop reminders', value: true),
      );
      if (yes != true) return;
    }
    await run(
      () => r.configure({
        'modules': {...r.preferences['modules'] as Map, name: value},
      }),
    );
  }

  Future<void> test() async {
    setState(() => problem = note = null);
    try {
      final sent = await r.sendTest();
      if (mounted) {
        setState(
          () => note = sent
              ? 'Test sent. If nothing showed, check your device’s notification settings.'
              : 'This is the demo, so nothing was sent.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => problem = 'The test couldn’t be sent. Try again.');
      }
    }
  }

  Widget statusCard() {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final set = setReminders(r.rows);
    final android = !isDesktop(context);
    final (headline, detail) = !r.available
        ? (
            'Reminders aren’t available here',
            'Everything stays in the app. Check your device’s settings, then try again.',
          )
        : !r.on
        ? (
            'Reminders are off on this device',
            'Turn them on and this device reminds you. Nothing changes in your records.',
          )
        : r.blocked
        ? (
            'Your device is blocking these',
            android
                ? 'To allow them: Settings › Apps › Salapiya › Notifications.'
                : 'To allow them: Settings › System › Notifications.',
          )
        : (
            set == 0
                ? 'Reminders are on, with nothing set'
                : set == 1
                ? 'Reminders are on, 1 set'
                : 'Reminders are on, $set set',
            r.unknown
                ? 'Windows hasn’t said whether these can show. Send a test to check.'
                : r.capability,
          );
    return OverviewCard(
      key: const ValueKey('life-reminders-status'),
      title: 'This device',
      accent: true,
      corner: !r.available
          ? null
          : AppSwitch(
              key: const ValueKey('life-reminders-on'),
              label: 'Reminders on this device',
              value: r.on,
              onChanged: (v) => v
                  ? run(() => r.configure({'enabled': true}, request: true))
                  : turnOff(),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(headline, style: text.titleSmall),
          const SizedBox(height: Space.xxs),
          Text(detail, style: text.bodySmall?.copyWith(color: c.secondary)),
          const SizedBox(height: Space.xxs),
          Text(
            'Only the nearest 128 within 90 days are set. Reminders never complete anything or change your records, and they’re set per device.',
            style: text.bodySmall?.copyWith(color: c.secondary),
          ),
          if (r.failed) ...[
            const SizedBox(height: Space.sm),
            const InlineNotice(
              'Reminders couldn’t be updated. Your records are fine. Try again.',
              tone: NoticeTone.warning,
              live: true,
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: Space.sm),
            InlineNotice(note!, live: true),
          ],
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              if (r.on && !r.blocked && r.available)
                AppButton.secondary(
                  'Send a test',
                  key: const ValueKey('life-reminders-test'),
                  onPressed: test,
                ),
              if (r.on)
                AppButton.tertiary(
                  'Check again',
                  key: const ValueKey('life-reminders-recheck'),
                  onPressed: () => run(r.recheck),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget comingCard(BuildContext context, PrototypeSession session) {
    final rows = comingReminders(r.rows, source.today);
    return OverviewCard(
      key: const ValueKey('life-reminders-coming'),
      title: 'Coming reminders',
      caption: 'Nearest first',
      child: rows.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              title: 'Nothing to remind you of',
              message: 'Events, tasks and dues within 90 days show here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListGroup(
                  children: [
                    for (final row in rows.take(shown))
                      reminderTile(context, session, row, r.timezone),
                  ],
                ),
                if (rows.length > shown)
                  ListEnd(
                    label: '${rows.length - shown} more',
                    onPressed: () => openDemoPage<void>(
                      context,
                      LifeRemindersPage(session: session),
                      'life/reminders/all',
                      title: 'Coming reminders',
                    ),
                  )
                else
                  const ListEnd(),
              ],
            ),
    );
  }

  Widget quietCard() {
    final prefs = r.preferences;
    TimeOfDay at(String key) {
      final p = (prefs[key] as String).split(':');
      return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }

    String hhmm(TimeOfDay v) =>
        '${'${v.hour}'.padLeft(2, '0')}:${'${v.minute}'.padLeft(2, '0')}';
    Future<void> set(String key, TimeOfDay v) async {
      setState(() => quietProblem = null);
      try {
        await r.configure({key: hhmm(v)});
      } on FormatException catch (e) {
        if (mounted) setState(() => quietProblem = e.message);
      }
    }

    return OverviewCard(
      key: const ValueKey('life-reminders-quiet'),
      title: 'Quiet hours',
      caption: 'Reminders wait until these end',
      corner: AppSwitch(
        key: const ValueKey('life-reminders-quiet-on'),
        label: 'Quiet hours',
        value: prefs['quiet'] == true,
        onChanged: (v) => run(() => r.configure({'quiet': v})),
      ),
      child: CompactForm(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TimeField(
              key: const ValueKey('life-field-start'),
              label: 'Start',
              value: at('start'),
              onChanged: (v) => set('start', v),
            ),
            SizedBox(height: CompactForm.fieldGap(context)),
            TimeField(
              key: const ValueKey('life-field-end'),
              label: 'End',
              value: at('end'),
              errorText: quietProblem,
              onChanged: (v) => set('end', v),
            ),
            SizedBox(height: CompactForm.fieldGap(context)),
            SearchPickerField(
              key: const ValueKey('life-field-reminder-timezone'),
              label: 'Timezone',
              value: prefs['timezone'] as String,
              helper: 'Due dates remind you at 9:00 AM here too.',
              searchLabel: 'Search timezones',
              options: [
                ('Device', 'This device’s timezone'),
                ...timezoneOptions(),
              ],
              onChanged: (v) => run(() => r.configure({'timezone': v})),
            ),
          ],
        ),
      ),
    );
  }

  Widget showCard() {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    final showDate = r.preferences['showDate'] == true;
    return OverviewCard(
      key: const ValueKey('life-reminders-show'),
      title: 'What may show',
      caption: 'On a locked screen too',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: c.subtle,
              borderRadius: BorderRadius.circular(Radii.controlOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminderTitle, style: text.titleSmall),
                const SizedBox(height: Space.xxs),
                Text(
                  reminderBody(showDate: showDate, date: source.today),
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.sm),
          SwitchRow(
            label: 'Include the date',
            value: showDate,
            onChanged: (v) => run(() => r.configure({'showDate': v})),
            switchKey: const ValueKey('life-reminders-date'),
          ),
          Text(
            'Titles, amounts, company names, contacts and notes never show.',
            style: text.bodySmall?.copyWith(color: c.secondary),
          ),
        ],
      ),
    );
  }

  Widget typesCard() {
    final modules = r.preferences['modules'] as Map? ?? const {};
    return OverviewCard(
      key: const ValueKey('life-reminders-types'),
      title: 'By type',
      caption: 'These don’t change what the Calendar shows',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final m in reminderModules)
            SwitchRow(
              label: lifeModuleName(m),
              value: modules[m] == true,
              onChanged: (v) => module(m, v),
              switchKey: ValueKey('life-reminders-module-$m'),
            ),
        ],
      ),
    );
  }

  Widget logCard(BuildContext context, PrototypeSession session) =>
      OverviewCard(
        key: const ValueKey('life-reminders-log'),
        title: 'What happened',
        caption: 'Set means your device has it, not that you saw it',
        child: FutureBuilder<List<ReminderLog>>(
          future: log,
          builder: (context, snapshot) {
            final rows = snapshot.data ?? const <ReminderLog>[];
            if (rows.isEmpty) {
              return const EmptyState(
                icon: Icons.history,
                title: 'Nothing yet',
                message: 'Reminders that have gone by show here.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListGroup(
                  children: [
                    for (final row in rows.take(8))
                      AdaptiveRow(
                        title: row.title,
                        subtitle:
                            '${reminderStamp(context, row.due, r.timezone)} · ${reminderLogLine(row.state)}',
                        onTap: row.row == null
                            ? null
                            : () => openLifeReminder(
                                context,
                                session,
                                row.row!.id,
                              ),
                      ),
                  ],
                ),
                const ListEnd(),
              ],
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final session = widget.hub.session;
    if (source.reminders == null) {
      return const SurfaceCard(
        child: EmptyState(
          icon: Icons.notifications_off_outlined,
          title: 'Reminders aren’t available here',
          message: 'Everything stays in the app.',
        ),
      );
    }
    final status = statusCard();
    final coming = comingCard(context, session);
    final quiet = quietCard();
    final show = showCard();
    final types = typesCard();
    final happened = logCard(context, session);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (problem != null) ...[
          InlineNotice(problem!, tone: NoticeTone.error, live: true),
          SizedBox(height: Space.cardGapOf(context)),
        ],
        DashboardGrid(
          key: const ValueKey('life-reminders'),
          cards: isDesktop(context)
              ? [
                  (status, 12, 12),
                  (coming, 8, 12),
                  (SideStack(top: quiet, rest: show), 4, 12),
                  (types, 6, 12),
                  (happened, 6, 12),
                ]
              : null,
          stacked: [status, coming, quiet, show, types, happened],
        ),
      ],
    );
  }
}

/// One reminder in a list. It opens that item's settings.
Widget reminderTile(
  BuildContext context,
  PrototypeSession session,
  ReminderRow row,
  String timezone,
) => AdaptiveRow(
  key: ValueKey('life-reminder-${row.id}'),
  title: row.title,
  subtitle: reminderLine(context, row, timezone),
  onTap: () => openLifeReminder(context, session, row.id),
);

/// Every coming reminder, nearest first.
class LifeRemindersPage extends StatefulWidget {
  const LifeRemindersPage({super.key, required this.session});
  final PrototypeSession session;
  @override
  State<LifeRemindersPage> createState() => _LifeRemindersPageState();
}

class _LifeRemindersPageState extends State<LifeRemindersPage> {
  static const page = 25;
  int shown = page;
  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ListenableBuilder(
      listenable: Listenable.merge([session, lifeHubOf(session)]),
      builder: (context, _) {
        final source = lifeSource(context, session);
        final reminders = source.reminders;
        final rows = reminders == null
            ? const <ReminderRow>[]
            : comingReminders(reminders.rows, source.today);
        return SectionPage(
          title: 'Coming reminders',
          caption: 'Nearest first',
          child: SurfaceCard(
            child: rows.isEmpty
                ? const EmptyState(
                    icon: Icons.notifications_none,
                    title: 'Nothing to remind you of',
                    message: 'Events, tasks and dues within 90 days show here.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListGroup(
                        children: [
                          for (final row in rows.take(shown))
                            reminderTile(
                              context,
                              session,
                              row,
                              reminders!.timezone,
                            ),
                        ],
                      ),
                      if (rows.length > shown)
                        ShowMore(
                          left: rows.length - shown,
                          onPressed: () => setState(() => shown += page),
                        )
                      else
                        const ListEnd(),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

/// Reminders as a page, for Profile until Chat 14.
class ReminderCenter extends StatelessWidget {
  const ReminderCenter({super.key, required this.session});
  final PrototypeSession session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([session, lifeHubOf(session)]),
    builder: (context, _) => SectionPage(
      title: 'Reminders',
      child: LifeRemindersTab(
        source: lifeSource(context, session),
        hub: lifeHubOf(session),
      ),
    ),
  );
}
