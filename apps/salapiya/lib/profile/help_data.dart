import '../prototype/scenarios.dart' show AppDestination;

/// Where an answer's link goes.
typedef HelpLink = ({String label, AppDestination destination, String? tab});

/// One question on the Help tab.
class HelpEntry {
  const HelpEntry(this.question, this.answer, {this.link});
  final String question, answer;
  final HelpLink? link;
  bool matches(String words) {
    final text = '$question $answer'.toLowerCase();
    return words
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .every(text.contains);
  }
}

/// A topic's questions, for one card.
class HelpTopic {
  const HelpTopic(this.title, this.entries);
  final String title;
  final List<HelpEntry> entries;
}

const helpTopics = [
  HelpTopic('Money', [
    HelpEntry(
      'How do I start with my accounts?',
      'Add each account with its balance and the day that balance was true. '
          'Then log newer activity after that day.',
      link: (
        label: 'Open Accounts',
        destination: AppDestination.money,
        tab: 'Accounts',
      ),
    ),
    HelpEntry(
      'Can I check a record before it saves?',
      'Yes. Review shows what a save will do before you confirm it.',
    ),
    HelpEntry(
      'What does archiving do?',
      'It keeps the history. Nothing is deleted.',
    ),
    HelpEntry(
      'Do budgets or money set aside protect my cash?',
      'No. They’re plans, and real spending still goes through.',
      link: (
        label: 'Open Planning',
        destination: AppDestination.money,
        tab: 'Planning',
      ),
    ),
    HelpEntry(
      'Does a recurring item log itself?',
      'No. Nothing is recorded when its date comes. Link the real record to '
          'it yourself.',
    ),
    HelpEntry(
      'Can I rely on the cash forecast?',
      'It’s an estimate you can only read. It says what it left out and '
          'what’s incomplete.',
    ),
    HelpEntry(
      'What can I import?',
      'Cash activity in pesos, in the layout Import shows. Check the columns, '
          'possible duplicates and every row you include.',
      link: (
        label: 'Open Import',
        destination: AppDestination.money,
        tab: 'Import',
      ),
    ),
    HelpEntry(
      'Can I import activity from before an account’s starting balance?',
      'Only with the exact earlier balance. Both change together.',
    ),
    HelpEntry(
      'What happens if I stop an import?',
      'Rows already imported stay. If Salapiya isn’t sure a group of rows '
          'went through, sort that out before trying again.',
    ),
  ]),
  HelpTopic('Debts and cards', [
    HelpEntry(
      'Is a loan income?',
      'No. Borrowed money isn’t income. It shows as what you owe.',
      link: (
        label: 'Open Debts',
        destination: AppDestination.debts,
        tab: 'Summary',
      ),
    ),
    HelpEntry(
      'Why does a debt keep so many figures apart?',
      'What you owe, what the lender’s records say, payments due, payments '
          'you made and payments without a breakdown are different things, '
          'so they stay separate.',
    ),
    HelpEntry(
      'What does an early payoff need?',
      'It has to match the lender’s records. Charges you avoided don’t undo '
          'expenses that were never logged.',
    ),
    HelpEntry(
      'How is a card purchase counted?',
      'Once, as spending and as card debt. A card payment lowers your cash '
          'and your card debt.',
      link: (
        label: 'Open Cards',
        destination: AppDestination.money,
        tab: 'Cards',
      ),
    ),
    HelpEntry(
      'Is available credit money I have?',
      'No. Available credit and paying more than you owe aren’t money you '
          'have.',
    ),
    HelpEntry(
      'Does a statement count as new spending?',
      'No. Statements and installment plans are proof of what’s owed, not '
          'new spending.',
    ),
    HelpEntry(
      'Why match a payment to a statement?',
      'What’s shown as due can’t be relied on until payments you haven’t '
          'matched are looked at.',
    ),
  ]),
  HelpTopic('Shared Expenses', [
    HelpEntry(
      'Does Salapiya move money between members?',
      'No. It tracks who owes whom. Payments happen elsewhere, and one counts '
          'once the person who received it confirms.',
      link: (
        label: 'Open Shared Expenses',
        destination: AppDestination.shared,
        tab: null,
      ),
    ),
    HelpEntry(
      'Do I need a connected account for a group?',
      'Yes. A profile on this device only can’t join a group, and keeps its '
          'private records.',
    ),
    HelpEntry(
      'Can a group see my private records?',
      'No. Members can’t see each other’s private records.',
    ),
  ]),
  HelpTopic('Life', [
    HelpEntry(
      'What shows on the Calendar?',
      'The Calendar and the Overview bring your Life items and money dues '
          'together. Each stays in its own record.',
      link: (
        label: 'Open Calendar',
        destination: AppDestination.life,
        tab: 'Calendar',
      ),
    ),
    HelpEntry(
      'Do reminders turn on by themselves?',
      'No. You turn them on for each device.',
      link: (
        label: 'Open Reminders',
        destination: AppDestination.life,
        tab: 'Reminders',
      ),
    ),
    HelpEntry(
      'Does a reminder finish anything?',
      'No. A reminder never completes a task or marks anything as paid.',
    ),
  ]),
  HelpTopic('Sync', [
    HelpEntry(
      'When do my records leave this device?',
      'Only after you connect a Google account and confirm.',
    ),
    HelpEntry(
      'What does signing out do?',
      'It ends this device’s sign-in. Records already here stay.',
    ),
    HelpEntry(
      'Can I open my files on another device?',
      'No. A file’s contents stay on the device you added it on.',
    ),
  ]),
  HelpTopic('Backups', [
    HelpEntry(
      'When should I back up?',
      'Before you change devices, at the least.',
    ),
    HelpEntry(
      'What do I need to restore?',
      'The backup and its recovery secret. Keep them in separate places.',
    ),
    HelpEntry(
      'Are my files in a backup?',
      'No. A backup lists your files but doesn’t hold them. Keep your '
          'originals.',
    ),
    HelpEntry(
      'Are my files safe?',
      'They’re encrypted on this device. They’re not virus-scanned.',
    ),
    HelpEntry(
      'Does restoring undo what has synced?',
      'No. A restore on a new device checks every record. It can’t undo what '
          'has already synced, or bring back a group place you’ve lost.',
    ),
  ]),
];
