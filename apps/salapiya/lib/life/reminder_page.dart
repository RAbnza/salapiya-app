import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_cards.dart' show civilLabel;
import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../features/life/application/life_controller.dart' show AgendaItem;
import '../prototype/scenarios.dart';
import 'device_reminders.dart';
import 'life_cards.dart' show lifeClock;
import 'life_controller.dart' show tzTime;
import 'life_data.dart';
import 'life_hub.dart';
import 'reminder_data.dart';

/// "Mon, 2 Nov, 9:00 AM", in the timezone reminders use.
String reminderStamp(BuildContext context, DateTime at, String timezone) {
  final (date, time) = tzTime(at.toUtc(), timezone);
  return '${civilLabel(date)}, ${lifeClock(context, time)}';
}

/// What will happen, in words.
String reminderLine(BuildContext context, ReminderRow r, String timezone) {
  final view = r.view;
  return switch (view.state) {
    ReminderState.scheduled =>
      'Reminds you ${reminderStamp(context, view.at!, timezone)}',
    ReminderState.snoozed =>
      'Snoozed until ${reminderStamp(context, view.at!, timezone)}',
    ReminderState.queued => 'Waiting: only the nearest 128 are set at a time',
    ReminderState.passed =>
      'Its time passed. Salapiya can’t tell whether it showed.',
    ReminderState.off => 'In the app only',
    ReminderState.blocked => 'Your device is blocking this',
    ReminderState.turnedOff => 'Turned off',
    ReminderState.moduleOff =>
      'Off for ${lifeModuleName(r.item.kind).toLowerCase()}',
    ReminderState.dismissed => 'Dismissed',
    ReminderState.far => 'More than 90 days away',
    ReminderState.checking => 'Checking',
  };
}

/// An item's row on the device, by an id with or without its `life:` start.
ReminderRow? reminderRowFor(LifeSource source, String id) => source
    .reminders
    ?.rows
    .where((r) => r.id == id || r.id == 'life:$id')
    .firstOrNull;

/// An item's reminder settings, from anywhere.
void openLifeReminder(
  BuildContext context,
  PrototypeSession session,
  String id,
) => openDemoPage<void>(
  context,
  LifeReminderPage(
    listenable: Listenable.merge([session, lifeHubOf(session)]),
    source: (context) => lifeSource(context, session),
    id: id,
  ),
  'life/reminder',
  title: 'Reminder',
);

/// A page's Reminder card: what will happen, and a way to change it.
class ReminderSummary extends StatelessWidget {
  const ReminderSummary({super.key, required this.session, required this.item});
  final PrototypeSession session;
  final AgendaItem item;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([session, lifeHubOf(session)]),
    builder: (context, _) {
      final source = lifeSource(context, session);
      final row = reminderRowFor(source, item.id);
      final text = Theme.of(context).textTheme.bodyMedium;
      if (row == null) {
        return Text(
          'Reminders are set within 90 days of the date.',
          style: text,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            reminderLine(context, row, source.reminders!.timezone),
            style: text,
          ),
          const SizedBox(height: Space.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: CardLink(
              'Change reminder',
              key: const ValueKey('life-change-reminder'),
              onPressed: () => openLifeReminder(context, session, row.id),
            ),
          ),
        ],
      );
    },
  );
}

/// One item's reminder: when it fires, how to change that, and what it never
/// does. Only what applies is offered.
class LifeReminderPage extends StatefulWidget {
  const LifeReminderPage({
    super.key,
    required this.listenable,
    required this.source,
    required this.id,
  });
  final Listenable listenable;
  final LifeSource Function(BuildContext context) source;
  final String id;
  @override
  State<LifeReminderPage> createState() => _LifeReminderPageState();
}

class _LifeReminderPageState extends State<LifeReminderPage> {
  String? problem;

  Future<void> run(
    LifeReminders r,
    ReminderRow row,
    String mode,
    String action,
  ) async {
    setState(() => problem = null);
    try {
      await r.choose(row, mode, action);
    } on FormatException catch (e) {
      if (mounted) setState(() => problem = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => problem = 'That didn’t work. Nothing changed.');
      }
    }
  }

  Future<void> turnOff(LifeReminders r, ReminderRow row) async {
    final yes = await showAppDialog<bool>(
      context,
      title: 'Turn off this reminder?',
      body: const Text(
        'It won’t remind you on this device. The item stays on your calendar, and your other devices keep their reminders.',
      ),
      primary: const ModalAction('Turn off', value: true),
    );
    if (yes == true) await run(r, row, 'Off', 'Planned');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.listenable,
    builder: (context, _) {
      final source = widget.source(context);
      final reminders = source.reminders;
      final row = reminderRowFor(source, widget.id);
      if (reminders == null || row == null) {
        return const SectionPage(
          title: 'Reminder',
          child: SurfaceCard(
            child: EmptyState(
              icon: Icons.notifications_none,
              title: 'There’s no reminder for this',
              message: 'It may be finished, or more than 90 days away. Calendar still shows what’s coming up.',
            ),
          ),
        );
      }
      final text = Theme.of(context).textTheme;
      final c = CraftTheme.of(context);
      final allDay = row.allDay;
      final when = OverviewCard(
        key: const ValueKey('life-reminder-when'),
        title: 'When it reminds you',
        accent: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              reminderLine(context, row, reminders.timezone),
              style: text.titleSmall,
            ),
            if (row.view.returned) ...[
              const SizedBox(height: Space.xxs),
              Text(
                'You dismissed this, then the item changed, so it came back.',
                style: text.bodySmall?.copyWith(color: c.secondary),
              ),
            ],
            if (allDay) ...[
              const SizedBox(height: Space.xxs),
              Text(
                'All-day items and due dates remind you at 9:00 AM.',
                style: text.bodySmall?.copyWith(color: c.secondary),
              ),
            ],
          ],
        ),
      );
      final change = OverviewCard(
        key: const ValueKey('life-reminder-change'),
        title: 'Change reminder',
        child: CompactForm(
          child: OptionPicker<String>(
            key: const ValueKey('life-reminder-mode'),
            label: 'Remind me',
            style: PickerStyle.radio,
            value: row.turnedOff ? null : row.mode,
            options: [
              for (final mode in reminderChoices(allDay, row.mode))
                PickerOption(
                  value: mode,
                  label: reminderModeLabel(mode, allDay),
                ),
            ],
            onChanged: (mode) => run(reminders, row, mode, 'Planned'),
          ),
        ),
      );
      final actions = <Widget>[
        if (row.canDismiss)
          AppButton.secondary(
            'Dismiss',
            key: const ValueKey('life-reminder-dismiss'),
            onPressed: () => run(reminders, row, row.mode, 'Dismissed'),
          ),
        if (row.canSnooze)
          AppButton.secondary(
            'Snooze 1 hour',
            key: const ValueKey('life-reminder-snooze'),
            onPressed: () => run(reminders, row, row.mode, 'Snoozed 1 hour'),
          ),
        if (row.dismissed)
          AppButton.secondary(
            'Bring back',
            key: const ValueKey('life-reminder-restore'),
            onPressed: () => run(reminders, row, row.mode, 'Restored'),
          ),
        if (row.turnedOff)
          AppButton.secondary(
            'Turn on',
            key: const ValueKey('life-reminder-on'),
            onPressed: () => run(reminders, row, 'Inherited', 'Planned'),
          )
        else
          AppButton.tertiary(
            'Turn off',
            key: const ValueKey('life-reminder-off'),
            onPressed: () => turnOff(reminders, row),
          ),
      ];
      final what = OverviewCard(
        key: const ValueKey('life-reminder-actions'),
        title: 'What you can do',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(spacing: Space.sm, runSpacing: Space.sm, children: actions),
            const SizedBox(height: Space.md),
            Text(
              'This only changes the reminder on this device. It never completes anything or marks anything as paid.',
              style: text.bodySmall?.copyWith(color: c.secondary),
            ),
          ],
        ),
      );
      return SectionPage(
        title: row.title,
        caption: detailLine([
          'Reminder',
          if (row.item.date.isNotEmpty) civilLabel(row.item.date),
        ]),
        actions: [
          AppButton.secondary(
            'Open item',
            key: const ValueKey('life-reminder-open'),
            onPressed: () => source.actions.openItem(row.item),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (problem != null) ...[
              InlineNotice(problem!, tone: NoticeTone.error, live: true),
              SizedBox(height: Space.cardGapOf(context)),
            ],
            DashboardGrid(
              cards: isDesktop(context)
                  ? [(SideStack(top: when, rest: what), 7, 12), (change, 5, 12)]
                  : null,
              stacked: [when, change, what],
            ),
          ],
        ),
      );
    },
  );
}
