import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import 'shared_bill_form.dart' show lostResponseMessage, lostResponseTitle;
import 'shared_data.dart';
import 'shared_domain.dart';
import 'shared_hub.dart';
import 'shared_people_data.dart';
import 'shared_repository.dart';

/// Changes to a group and who's in it: short forms, so a dialog on Windows and
/// a sheet on Android (§5). All of them need a connection. Ids are made when a
/// form opens, so pressing again after a lost answer repeats the same command
/// and the server answers from its receipt. A refused command stays on record,
/// so a form that would send a stale group version stops first.

/// Reasons go in the group's history, where everyone can read them.
const _everyoneSees = 'Everyone in the group can see this.';

/// What a change does, in two short groups.
class _Effects extends StatelessWidget {
  const _Effects({required this.changes, required this.stays});
  final String changes, stays;
  @override
  Widget build(BuildContext context) {
    final c = CraftTheme.of(context);
    final text = Theme.of(context).textTheme;
    Widget group(String label, String words) => Padding(
      padding: EdgeInsets.only(bottom: CompactForm.fieldGap(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: text.labelMedium?.copyWith(color: c.secondary)),
          const SizedBox(height: Space.xxs),
          Text(words, style: text.bodyMedium),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [group('What changes', changes), group('What stays', stays)],
    );
  }
}

/// The form behind each change: its effects, its fields, and sending once.
class _ChangeForm extends StatefulWidget {
  const _ChangeForm({
    super.key,
    required this.hub,
    required this.group,
    required this.op,
    required this.values,
    this.effects,
    this.intro,
    this.people,
    this.peopleLabel,
    this.reason = false,
    this.reasonLabel = 'Why',
    this.text,
  });
  final SharedHub hub;
  final SharedGroup group;
  final String op;

  /// The command, from what was answered.
  final SharedJson Function(_Answers) values;
  final Widget? effects, intro;

  /// Who this is about, when the form has to ask.
  final List<SharedMember>? people;
  final String? peopleLabel;
  final bool reason;
  final String reasonLabel;

  /// A typed answer: its label, helper, what's wrong with an entry, and key.
  final _TextAnswer? text;
  @override
  State<_ChangeForm> createState() => _ChangeFormState();
}

class _TextAnswer {
  const _TextAnswer(this.label, this.check, {this.helper, this.fieldKey});
  final String label;
  final String? helper;
  final String? fieldKey;

  /// What's wrong with [value], or null when it's fine.
  final String? Function(String value) check;
}

/// What the user answered.
class _Answers {
  const _Answers(this.person, this.reason, this.text);
  final String? person;
  final String reason, text;
}

class _ChangeFormState extends State<_ChangeForm> {
  /// Made when the form opens. A refusal is the only thing that replaces it.
  String command = newLocalId();
  final reason = TextEditingController(), text = TextEditingController();
  String? person;
  String? reasonError, textError, personError, problem;
  bool lost = false, stale = false;

  @override
  void dispose() {
    reason.dispose();
    text.dispose();
    super.dispose();
  }

  /// Saves, and says whether the modal can close.
  Future<bool> save() async {
    final source = widget.hub.source();
    final why = reason.text.trim(), typed = text.text.trim();
    setState(() {
      personError = widget.people != null && person == null
          ? 'Choose someone.'
          : null;
      reasonError = widget.reason && why.isEmpty ? 'Say why.' : null;
      textError = widget.text?.check(typed);
      problem = null;
    });
    if (personError != null || reasonError != null || textError != null) {
      return false;
    }
    final latest = source.groups
        .where((g) => g.id == widget.group.id)
        .firstOrNull;
    if (!lost && latest != null && latest.version != widget.group.version) {
      setState(() => stale = true);
      return false;
    }
    if (!source.online) {
      setState(
        () => problem = 'This needs a connection. What you entered is kept.',
      );
      return false;
    }
    try {
      await source.writer.submit(
        widget.group.id,
        widget.op,
        widget.values(_Answers(person, why, typed)),
        version: widget.group.version,
        id: command,
      );
      return true;
    } on LocalRuleException catch (e) {
      // Refused: the next try is a new command.
      setState(() {
        problem = sharedReason(e.message);
        command = newLocalId();
        lost = false;
      });
    } catch (_) {
      setState(() => lost = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final gap = SizedBox(height: CompactForm.fieldGap(context));
    final text = widget.text;
    return CompactForm(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lost) ...[
            const InlineNotice(
              lostResponseMessage,
              title: lostResponseTitle,
              tone: NoticeTone.warning,
              live: true,
            ),
            gap,
          ],
          if (stale) ...[
            const InlineNotice(
              'The group changed while you were working. Close this and check it, then try again.',
              title: 'This group changed',
              tone: NoticeTone.warning,
              live: true,
            ),
            gap,
          ],
          if (problem != null) ...[
            InlineNotice(problem!, tone: NoticeTone.error, live: true),
            gap,
          ],
          if (widget.intro != null) ...[widget.intro!, gap],
          ?widget.effects,
          if (widget.people != null) ...[
            OptionPicker<String>(
              key: const ValueKey('change-person'),
              label: widget.peopleLabel ?? 'Who',
              required: true,
              errorText: personError,
              value: person,
              options: [
                for (final m in widget.people!)
                  PickerOption(value: m.person, label: m.name),
              ],
              onChanged: lost ? null : (x) => setState(() => person = x),
            ),
            gap,
          ],
          if (text != null) ...[
            HelpTextField(
              key: ValueKey(text.fieldKey ?? 'change-text'),
              label: text.label,
              controller: this.text,
              required: true,
              readOnly: lost,
              helper: text.helper,
              errorText: textError,
            ),
            if (widget.reason) gap,
          ],
          if (widget.reason)
            HelpTextField(
              key: const ValueKey('change-reason'),
              label: widget.reasonLabel,
              controller: reason,
              required: true,
              readOnly: lost,
              helper: _everyoneSees,
              errorText: reasonError,
            ),
        ],
      ),
    );
  }
}

Future<bool> _open(
  BuildContext context, {
  required String title,
  required String action,
  required _ChangeForm Function(GlobalKey<_ChangeFormState>) form,
  bool destructive = false,
}) async {
  final key = GlobalKey<_ChangeFormState>();
  final done = await showAdaptiveModal<bool>(
    context,
    title: title,
    purpose: ModalPurpose.choice,
    body: form(key),
    primary: ModalAction(
      action,
      value: true,
      destructive: destructive,
      onPressed: () async => await key.currentState?.save() ?? false,
    ),
  );
  return done == true;
}

/// Add a person: someone with no account, who the owner answers for.
Future<bool> showAddPerson(BuildContext context, SharedHub hub, SharedGroup g) {
  // One id for this person, so a lost answer can't add them twice.
  final participant = newLocalId();
  return _open(
    context,
    title: 'Add a person',
    action: 'Add person',
    form: (key) => _ChangeForm(
      key: key,
      hub: hub,
      group: g,
      op: 'manual',
      text: _TextAnswer(
        'Their name',
        (v) => v.isEmpty ? 'Enter their name.' : null,
        helper: 'They won’t sign in. You log and answer payments for them.',
        fieldKey: 'person-name',
      ),
      values: (a) => {'participant': participant, 'name': a.text},
    ),
  );
}

/// The server's own check on an address.
final _email = RegExp(r'^[^@ ]+@[^@ ]+\.[^@ ]+$');

/// Invite someone, by the Google account they sign in with. With [person],
/// the invitation is for them to take that person's place. The token stays
/// the same for the whole form, so a lost answer asks about this invitation
/// and the code shown at the end is the one the server has.
Future<void> showInvite(
  BuildContext context,
  SharedHub hub,
  SharedGroup g, {
  String? person,
}) async {
  final token = SharedRepository.invitationToken();
  final hash = SharedRepository.tokenHash(token);
  final sent = await _open(
    context,
    title: person == null
        ? 'Invite someone'
        : 'Invite ${g.personName(person)} to take this place',
    action: 'Send invitation',
    form: (key) => _ChangeForm(
      key: key,
      hub: hub,
      group: g,
      op: 'invite',
      intro: person == null
          ? null
          : Text(
              'They’ll see the group’s history and take over this place. Payments you confirmed for them stay marked that way. If the group changes before they accept, this stops working and you can send a new one.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
      text: _TextAnswer(
        'Their Google email',
        (v) => _email.hasMatch(v) ? null : 'Enter an email like ana@gmail.com.',
        helper: 'Only this account can use the invitation.',
        fieldKey: 'invite-email',
      ),
      values: (a) => {'email': a.text, 'hash': hash, 'participant': ?person},
    ),
  );
  if (sent && context.mounted) {
    await _showCode(context, '${g.id}.$token', hub.source().demo);
  }
}

/// The code, once. The app keeps only its hash.
Future<void> _showCode(BuildContext context, String code, bool demo) async {
  await showAdaptiveModal<void>(
    context,
    title: 'Share this code',
    body: StatefulBuilder(
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            code,
            key: const ValueKey('invite-code'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Space.md),
          Text(
            demo ? 'This is the demo, so this code won’t work.' : 'It works once, for seven days, and only for that Google account. This code won’t show again.',
          ),
        ],
      ),
    ),
    primary: ModalAction<void>(
      'Copy code',
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: code));
        return false;
      },
    ),
    secondary: const ModalAction.cancel(label: 'Done'),
  );
}

/// Stop an invitation. It has no reason: the server takes none.
Future<bool> showRevoke(
  BuildContext context,
  SharedHub hub,
  SharedGroup g,
  OpenInvitation invitation,
) => _open(
  context,
  title: 'Revoke this invitation?',
  action: 'Revoke invitation',
  destructive: true,
  form: (key) => _ChangeForm(
    key: key,
    hub: hub,
    group: g,
    op: 'revoke',
    effects: const _Effects(
      changes: 'The code stops working.',
      stays: 'Everyone in the group, and every record. You can send a new one.',
    ),
    values: (_) => {'invitation': invitation.id},
  ),
);

String _balance(SharedGroup g, String person, SharedHub hub) {
  final b = personBreakdown(g, person);
  final amount = hub.source().amount;
  if (b == null) return 'Their balance stays.';
  return b.position == BigInt.zero
      ? 'They’re all square.'
      : b.position > BigInt.zero
      ? 'They’re still owed ${amount(b.position)}.'
      : 'They still owe ${amount(-b.position)}.';
}

/// Leave the group. The owner can't: the tab says so and doesn't offer this.
Future<bool> showLeave(
  BuildContext context,
  SharedHub hub,
  SharedGroup g,
  String me,
) {
  final b = personBreakdown(g, me);
  final amount = hub.source().amount;
  final standing = b == null || b.position == BigInt.zero
      ? 'Your balance stays as it is.'
      : b.position > BigInt.zero
      ? 'You’re still owed ${amount(b.position)}.'
      : 'You still owe ${amount(-b.position)}. Leaving doesn’t forgive it.';
  return _open(
    context,
    title: 'Leave this group?',
    action: 'Leave group',
    destructive: true,
    form: (key) => _ChangeForm(
      key: key,
      hub: hub,
      group: g,
      op: 'leave',
      effects: _Effects(
        changes: 'You can’t add bills or payments here, and you won’t see anything new. To come back, you’d need a new invitation.',
        stays:
            '$standing Your earlier bills and payments stay, and you can still answer payments on them.',
      ),
      reason: true,
      reasonLabel: 'Why you’re leaving',
      values: (a) => {'reason': a.reason, 'participant': me},
    ),
  );
}

/// Remove someone. Without [person] it asks who.
Future<bool> showRemove(
  BuildContext context,
  SharedHub hub,
  SharedGroup g, {
  String? person,
}) {
  final name = person == null ? 'This person' : g.personName(person);
  return _open(
    context,
    title: person == null ? 'Remove someone' : 'Remove $name?',
    action: 'Remove from group',
    destructive: true,
    form: (key) => _ChangeForm(
      key: key,
      hub: hub,
      group: g,
      op: 'remove',
      people: person == null ? removableMembers(g) : null,
      peopleLabel: 'Who',
      effects: _Effects(
        changes:
            '$name can’t add bills or payments here, and won’t see anything new.',
        stays:
            '${person == null ? 'Their balance stays.' : _balance(g, person, hub)} Removing someone doesn’t forgive what they owe. Their earlier bills and payments stay.',
      ),
      reason: true,
      reasonLabel: 'Why you’re removing them',
      values: (a) => {'reason': a.reason, 'participant': person ?? a.person},
    ),
  );
}

/// Make someone else the owner. Without [person] it asks who.
Future<bool> showTransfer(
  BuildContext context,
  SharedHub hub,
  SharedGroup g, {
  String? person,
}) => _open(
  context,
  title: person == null
      ? 'Make someone else the owner'
      : 'Make ${g.personName(person)} the owner?',
  action: 'Make owner',
  form: (key) => _ChangeForm(
    key: key,
    hub: hub,
    group: g,
    op: 'transfer',
    people: person == null ? ownerCandidates(g) : null,
    peopleLabel: 'New owner',
    effects: const _Effects(
      changes: 'They add people, send invitations and archive the group. You become a member, and only they can make you the owner again.',
      stays: 'Every bill, payment and balance.',
    ),
    reason: true,
    reasonLabel: 'Why you’re changing the owner',
    values: (a) => {'reason': a.reason, 'participant': person ?? a.person},
  ),
);

/// Archive a group, or restore it. The action follows from where it stands,
/// so this can't send the state the group is already in.
Future<bool> showArchive(BuildContext context, SharedHub hub, SharedGroup g) {
  final restoring = g.archived;
  return _open(
    context,
    title: restoring ? 'Restore this group?' : 'Archive this group?',
    action: restoring ? 'Restore group' : 'Archive group',
    destructive: !restoring,
    form: (key) => _ChangeForm(
      key: key,
      hub: hub,
      group: g,
      op: 'archive',
      effects: _Effects(
        changes: restoring ? 'People can add bills and payments here again.' : 'Nobody can add bills or payments. Payments already waiting can still be answered. You can restore it later.',
        stays: 'Every bill, payment and balance. Archiving doesn’t clear what anyone owes.',
      ),
      reason: true,
      reasonLabel: restoring
          ? 'Why you’re restoring it'
          : 'Why you’re archiving it',
      values: (a) => {'reason': a.reason, 'archived': !restoring},
    ),
  );
}
