import 'package:flutter/material.dart';

import '../app/demo_routes.dart';
import '../app/overview_data.dart';
import '../features/life/application/life_controller.dart'
    show AgendaItem, LifeKind;
import '../features/life/presentation/life_screen.dart';
import '../finance/debt_data.dart';
import '../finance/debt_screen.dart' show localDebtsSource;
import '../finance/money_details.dart' show localMoneySource;
import '../local/finance_domain.dart';
import '../local/local_runtime.dart';
import '../local/local_store.dart';
import '../prototype/scenarios.dart';
import 'life_controller.dart';
import 'life_data.dart';
import 'life_demo.dart';
import 'life_domain.dart';
import 'life_forms.dart';
import 'life_pages_detail.dart';
import 'device_reminders.dart' show reminderModules;
import 'life_reviews.dart';
import 'reminder_data.dart';
import 'reminder_page.dart' show ReminderSummary;
import 'reminders_tab.dart' show ReminderCenter;
import 'tasks_tab.dart' show openLifeTask;
import 'life_settings.dart';

/// What Life is showing, kept outside the section's screen: the shell keys
/// that screen on its tab, so anything held there is lost on every tab change.
class LifeHub extends ChangeNotifier {
  LifeHub(this.session);
  final PrototypeSession session;

  String? _selected, _month;

  /// Agenda instead of the month.
  bool agenda = false;

  /// One module on the Calendar, or 'All'.
  String show = 'All';
  String query = '';

  /// The Tasks list's filter and search.
  TaskFilter taskFilter = TaskFilter.active;
  String taskQuery = '';

  /// What went wrong with a one-tap action.
  String? problem;

  /// Goes to a Life tab; the shell sets this.
  ValueChanged<String>? openTab;

  /// The day on show.
  String selected(String today) => _selected ?? today;

  /// The first day of the month on show.
  String month(String today) => _month ?? monthStart(selected(today));

  void select(String date) {
    _selected = date;
    _month = monthStart(date);
    notifyListeners();
  }

  void moveMonth(String today, int by) {
    final m = DateTime.parse(month(today));
    final next = DateTime.utc(m.year, m.month + by);
    _month = next.toIso8601String().substring(0, 10);
    notifyListeners();
  }

  void setAgenda(bool value) {
    agenda = value;
    notifyListeners();
  }

  void setShow(String module) {
    show = module;
    notifyListeners();
  }

  void setQuery(String words) {
    query = words;
    notifyListeners();
  }

  void setTaskFilter(TaskFilter filter) {
    taskFilter = filter;
    notifyListeners();
  }

  void setTaskQuery(String words) {
    taskQuery = words;
    notifyListeners();
  }

  /// Something outside the hub changed what its screens show.
  void touch() => notifyListeners();

  void setProblem(String? message) {
    problem = message;
    notifyListeners();
  }

  /// What Life shows on this device: the same value on both builds.
  Map<String, dynamic> _demoView = {
    'tabs': {
      for (final tab in const ['Tasks', 'Learning', 'Books', 'Career'])
        tab: true,
    },
    'calendar': {for (final module in reminderModules) module: true},
    'timezone': 'Asia/Manila',
  };
  Map<String, dynamic> get view {
    final life = session.life;
    return life is DurableLifeController ? life.viewPreferences : _demoView;
  }

  Future<void> saveView(Map<String, dynamic> next) async {
    final life = session.life;
    if (life is DurableLifeController) {
      await life.saveViewPreferences(next);
    } else {
      validateLifeView(next);
      _demoView = next;
    }
    notifyListeners();
  }

  bool tabShown(String tab) => (view['tabs'] as Map)[tab] != false;
  bool calendarShown(String module) => (view['calendar'] as Map)[module] != false;

  late final demoReminders = DemoReminders(this);

  DemoLifeWriter? _writer;
  DemoLifeWriter demoWriter(DemoLife life, String today) {
    if (_writer?.today != today || !identical(_writer?.life, life)) {
      _writer = DemoLifeWriter(life, today);
    }
    return _writer!;
  }
}

final _hubs = Expando<LifeHub>();

/// The session's hub: the shell, the Overview and notifications all land on
/// the same day.
LifeHub lifeHubOf(PrototypeSession session) =>
    _hubs[session] ??= LifeHub(session);

/// What Life reads on this build.
LifeSource lifeSource(BuildContext context, PrototypeSession session) =>
    session is LocalSession
    ? localLifeSource(context, session)
    : demoLifeSource(context, session);

/// Edits that couldn't be saved.
void openLifeChecks(BuildContext context, PrototypeSession session) =>
    openDemoPage<void>(
      context,
      LifeChecksPage(
        listenable: session,
        source: (context) => lifeSource(context, session),
      ),
      'life/checks',
      title: 'Changes to check',
    );

/// A debt's page from its schedule's id, or the record if no debt has it.
void openDebtDue(DebtsSource debts, String schedule) {
  final debt = overviewDebtProgress(
    debts.snapshot,
    debts.today,
  ).where((d) => d.due.schedule?.id == schedule).firstOrNull;
  debt == null
      ? debts.actions.openRecord(schedule)
      : debts.actions.openDebt(debt);
}

/// A dated item's reminder, on its page.
Widget lifeReminderControls(PrototypeSession session, AgendaItem item) =>
    ReminderSummary(session: session, item: item);

/// Reminders, on its tab; or as a page outside the shell.
void openLifeReminders(BuildContext context, PrototypeSession session) {
  final open = lifeHubOf(session).openTab;
  if (open != null) {
    open('Reminders');
    return;
  }
  openDemoPage<void>(
    context,
    ReminderCenter(session: session),
    'life/reminders',
  );
}

/// Saves through the real rules and the encrypted store.
class LocalLifeWriter implements LifeWriter {
  LocalLifeWriter(this.c);
  final DurableLifeController c;
  LocalStore get store => c.store;

  @override
  bool get demo => false;
  @override
  String get today => civilToday();
  @override
  String get timezone => c.displayTimezone;
  @override
  LifeRecord? record(String? id) => c.records[id];
  @override
  Future<Map<String, String>?> draft(String operation) async =>
      (await store.draft(operation))?['values'] as Map<String, String>?;
  @override
  Future<void> saveDraft(
    String operation,
    String command,
    Map<String, String> values,
  ) => store.saveDraft(operation, command, values);
  @override
  Future<void> discardDraft(String operation) =>
      store.discardDraft(operation);
  @override
  LifeCommand eventCommand(Map<String, String> v, {String? old}) =>
      c.eventCommand(v, old: old);
  @override
  Future<void> saveEvent(Map<String, String> v, {String? old}) async => c
      .saveEvent(v, old: c.events.where((e) => e.id == old).firstOrNull);
  @override
  Future<void> change(
    String id,
    int version,
    Map<String, String> fields,
    String reason,
  ) => c.change(id, version, fields, reason);
  @override
  LifeCommand taskCommand(Map<String, String> v, {String? old}) =>
      c.taskCommand(v, old: old);
  @override
  Future<void> saveTask(Map<String, String> v, {String? old}) async =>
      c.saveEntry(
        LifeKind.task,
        v,
        old: c.entries.where((e) => e.id == old).firstOrNull,
      );
  @override
  Future<void> useEdit(LifeCommand command, String original) async {
    await store.commitLife(command);
    // After a lost answer it may already be closed; a decision never changes.
    if (c.intents.any((i) => i['id'] == original && i['resolved_at'] != null)) {
      return;
    }
    await store.resolveLifeReview(original, command.id);
    await c.reload();
  }

  @override
  Future<void> keepCurrent(String original) async {
    await store.resolveLifeReview(original, null);
    await c.reload();
  }

  @override
  String savedLine(String command) =>
      c.intents.any(
        (i) =>
            i['id'] == command &&
            ['pending', 'accepted'].contains(i['state']),
      )
      ? 'Saved on this device. It’s waiting to sync.'
      : 'Saved.';
  @override
  Future<List<(String, LifeCommand)>> history(String id) =>
      store.lifeRecordHistory(id);
}

LifeSource localLifeSource(BuildContext context, LocalSession session) {
  final c = session.life as DurableLifeController;
  final finance = session.localFinance;
  return LifeSource(
    today: civilToday(),
    now: tzTime(DateTime.now().toUtc(), c.displayTimezone).$2,
    timezone: c.displayTimezone,
    complete: session.complete,
    lifeComplete: c.initialComplete,
    hidden: session.hideAmounts,
    amount: session.amount,
    records: c.records,
    snapshot: finance.snapshot,
    writer: LocalLifeWriter(c),
    visible: c.calendarVisible,
    waiting: session.pendingCount,
    error: c.error,
    reviews: lifeReviewRows(c.intents, c.records),
    restoring: c.intents
        .where((i) => i['resolved_at'] == null && i['state'] == 'restored')
        .length,
    reminders: c.device == null ? null : LocalReminders(c, session.finance),
    actions: LifeActions(
      addEvent: () => openEventForm(context, session),
      addTask: () => openTaskForm(context, session),
      editEvent: (id) => openEventForm(context, session, id: id),
      openEvent: (id) => openLifeEvent(context, session, id),
      editTask: (id) => openTaskForm(context, session, id: id),
      openTask: (id) => openLifeTask(context, session, id),
      openRow: (row) => openLifeRow(context, session, row),
      openItem: (item) => openLifeSource(context, session, item),
      openList: (page, title) =>
          openDemoPage<void>(context, page, 'life/list', title: title),
      reminders: () => openLifeReminders(context, session),
      preferences: () => openDemoPage<void>(
        context,
        LifeSettings(session: session),
        'life/settings',
      ),
      reminderFor: (item) => lifeReminderControls(session, item),
    ),
  );
}

/// A row's own page: an event's, a debt's, a statement's, or a recurring
/// item's. It never opens another copy of the section.
void openLifeRow(
  BuildContext context,
  LocalSession session,
  LifeRow row,
) => switch (row.module) {
  'Personal' => openLifeEvent(context, session, row.sourceId),
  'Tasks' => openLifeTask(context, session, row.sourceId),
  'Debts' => openDebtDue(
    localDebtsSource(context, session.localFinance, session),
    row.sourceId,
  ),
  'Cards' || 'Recurring' => localMoneySource(
    context,
    session.localFinance,
    session,
  ).actions.openItem(row.sourceId),
  _ => openLifeSource(context, session, row.item),
};
