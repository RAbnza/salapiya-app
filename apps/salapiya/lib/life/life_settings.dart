import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../prototype/scenarios.dart';
import 'device_reminders.dart';
import 'life_data.dart';
import 'life_forms.dart' show timezoneOptions;
import 'life_hub.dart';

/// What shows in Life on this device. Nothing here deletes a record or stops
/// a reminder.
class LifeSettings extends StatefulWidget {
  const LifeSettings({super.key, required this.session});
  final PrototypeSession session;
  @override
  State<LifeSettings> createState() => _LifeSettingsState();
}

class _LifeSettingsState extends State<LifeSettings> {
  String? problem;

  Future<void> save(LifeHub hub, Map<String, dynamic> next) async {
    setState(() => problem = null);
    try {
      await hub.saveView(next);
    } catch (_) {
      if (mounted) {
        setState(() => problem = 'That didn’t save. Nothing changed.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session, hub = lifeHubOf(session);
    return ListenableBuilder(
      listenable: Listenable.merge([session, hub]),
      builder: (context, _) {
        final view = hub.view;
        final tabs = view['tabs'] as Map, calendar = view['calendar'] as Map;
        final show = OverviewCard(
          key: const ValueKey('life-settings-tabs'),
          title: 'Show in Life',
          caption: 'Hiding a tab keeps everything in it',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final tab in const ['Tasks', 'Learning', 'Books', 'Career'])
                SwitchRow(
                  label: tab,
                  switchKey: ValueKey('life-setting-$tab'),
                  value: tabs[tab] != false,
                  onChanged: (v) => save(hub, {
                    ...view,
                    'tabs': {...tabs, tab: v},
                  }),
                ),
            ],
          ),
        );
        final onCalendar = OverviewCard(
          key: const ValueKey('life-settings-calendar'),
          title: 'Show on Calendar',
          caption: 'Reminders have their own switches',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final module in reminderModules)
                SwitchRow(
                  label: lifeModuleName(module),
                  switchKey: ValueKey('life-setting-calendar-$module'),
                  value: calendar[module] != false,
                  onChanged: (v) => save(hub, {
                    ...view,
                    'calendar': {...calendar, module: v},
                  }),
                ),
            ],
          ),
        );
        final zone = OverviewCard(
          key: const ValueKey('life-settings-timezone'),
          title: 'Timezone',
          child: CompactForm(
            child: SearchPickerField(
              key: const ValueKey('life-field-display-timezone'),
              label: 'Show times in',
              value: view['timezone'] as String,
              helper: 'Events keep their own timezone. All-day items and due dates never move.',
              searchLabel: 'Search timezones',
              options: timezoneOptions(),
              onChanged: (v) => save(hub, {...view, 'timezone': v}),
            ),
          ),
        );
        return SectionPage(
          title: 'Life preferences',
          caption: 'These stay on this device.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (problem != null) ...[
                InlineNotice(problem!, tone: NoticeTone.error, live: true),
                SizedBox(height: Space.cardGapOf(context)),
              ],
              DashboardGrid(
                cards: isDesktop(context)
                    ? [
                        // Together, so nothing empty sits beside the longer list.
                        (SideStack(top: show, rest: zone), 6, 12),
                        (onCalendar, 6, 12),
                      ]
                    : null,
                stacked: [show, onCalendar, zone],
              ),
            ],
          ),
        );
      },
    );
  }
}
