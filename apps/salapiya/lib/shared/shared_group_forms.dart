import 'package:flutter/material.dart';

import '../design_system/kit/kit.dart';
import '../design_system/theme.dart';
import '../local/finance_domain.dart';
import 'shared_bill_form.dart' show lostResponseMessage, lostResponseTitle;
import 'shared_data.dart';
import 'shared_domain.dart';
import 'shared_hub.dart';

/// Create a group and Join with a code: short forms, so a dialog on Windows
/// and a sheet on Android (§5). Ids are made when the form opens, so pressing
/// again after a lost answer repeats the same command, and the server answers
/// from its receipt.

/// Opens Create a group. Returns the new group's id.
Future<String?> showCreateGroup(BuildContext context, SharedHub hub) async {
  final form = GlobalKey<_CreateGroupState>();
  return showAdaptiveModal<String>(
    context,
    title: 'Create a group',
    purpose: ModalPurpose.choice,
    body: _CreateGroup(key: form, hub: hub),
    primary: ModalAction(
      'Add group',
      onPressed: () async => await form.currentState?.save() ?? false,
    ),
  );
}

class _CreateGroup extends StatefulWidget {
  const _CreateGroup({super.key, required this.hub});
  final SharedHub hub;
  @override
  State<_CreateGroup> createState() => _CreateGroupState();
}

class _CreateGroupState extends State<_CreateGroup> {
  late var group = newLocalId(), command = newLocalId();
  late final participant = newLocalId();
  final name = TextEditingController();
  late final display = TextEditingController(
    text: widget.hub.source().profileName,
  );
  String? nameError, displayError, problem;
  bool lost = false;

  @override
  void dispose() {
    name.dispose();
    display.dispose();
    super.dispose();
  }

  /// Saves, and says whether the modal can close.
  Future<bool> save() async {
    final source = widget.hub.source();
    final a = name.text.trim(), b = display.text.trim();
    setState(() {
      nameError = a.isEmpty ? 'Name your group.' : null;
      displayError = b.isEmpty ? 'Enter the name others will see.' : null;
      problem = null;
    });
    if (a.isEmpty || b.isEmpty) return false;
    try {
      await source.writer.submit(group, 'create', {
        'name': a,
        'display': b,
        'participant': participant,
      }, id: command);
      widget.hub.choose(group);
      return true;
    } on LocalRuleException catch (e) {
      // Refused: the next try is a new command.
      setState(() {
        problem = sharedReason(e.message);
        group = newLocalId();
        command = newLocalId();
        lost = false;
      });
    } catch (_) {
      setState(() => lost = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => CompactForm(
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
          SizedBox(height: CompactForm.fieldGap(context)),
        ],
        if (problem != null) ...[
          InlineNotice(problem!, tone: NoticeTone.error, live: true),
          SizedBox(height: CompactForm.fieldGap(context)),
        ],
        HelpTextField(
          key: const ValueKey('group-name'),
          label: 'Group name',
          controller: name,
          required: true,
          // A lost answer freezes the values: the command must stay the same.
          readOnly: lost,
          hintText: 'Apartment, Boracay trip, Family',
          errorText: nameError,
        ),
        SizedBox(height: CompactForm.fieldGap(context)),
        HelpTextField(
          key: const ValueKey('group-display'),
          label: 'Your name in this group',
          controller: display,
          required: true,
          readOnly: lost,
          errorText: displayError,
        ),
      ],
    ),
  );
}

/// Opens Join with a code. Returns the group's id.
Future<String?> showJoinGroup(BuildContext context, SharedHub hub) async {
  final form = GlobalKey<_JoinGroupState>();
  return showAdaptiveModal<String>(
    context,
    title: 'Join with a code',
    purpose: ModalPurpose.choice,
    body: _JoinGroup(key: form, hub: hub),
    primary: ModalAction(
      'Continue',
      onPressed: () async {
        final state = form.currentState;
        return state != null && await state.review(context);
      },
    ),
  );
}

class _JoinGroup extends StatefulWidget {
  const _JoinGroup({super.key, required this.hub});
  final SharedHub hub;
  @override
  State<_JoinGroup> createState() => _JoinGroupState();
}

class _JoinGroupState extends State<_JoinGroup> {
  var command = newLocalId();
  late final participant = newLocalId();
  final code = TextEditingController();
  late final display = TextEditingController(
    text: widget.hub.source().profileName,
  );
  String? codeError, displayError, problem;
  bool lost = false;

  /// The group the lost answer was about. Its code may be used up by now, so
  /// the same command goes again instead of a new review.
  SharedGroup? joining;

  @override
  void dispose() {
    code.dispose();
    display.dispose();
    super.dispose();
  }

  Future<void> join(SharedGroup g, String token, String name) async {
    joining = g;
    await widget.hub.source().writer.submit(
      g.id,
      'accept',
      {
        'token': token,
        'consent': true,
        'display': name,
        'participant': participant,
      },
      version: g.version,
      id: command,
    );
    widget.hub.choose(g.id);
  }

  /// Asks the server about the code, shows what joining shares, and joins
  /// only if the user agrees. Cancelling there isn't a problem to report.
  Future<bool> review(BuildContext context) async {
    final source = widget.hub.source();
    final text = code.text.trim(), name = display.text.trim();
    setState(() {
      codeError = text.isEmpty ? 'Paste the invitation code.' : null;
      displayError = name.isEmpty ? 'Enter the name others will see.' : null;
      problem = null;
    });
    if (text.isEmpty || name.isEmpty) return false;
    try {
      final retrying = lost ? joining : null;
      if (retrying != null) {
        await join(retrying, text.split('.')[1], name);
        return true;
      }
      final review = await source.writer.reviewInvitation(text);
      final g = SharedGroup(object(review['document']));
      if (!context.mounted) return false;
      final claim = review['claim'] as String?;
      final agreed = await showAdaptiveModal<bool>(
        context,
        title: 'Join ${g.name}?',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(review['disclosure'] as String),
            const SizedBox(height: Space.md),
            FactRow('People', '${g.people.length}'),
            FactRow('Bills', '${g.bills.length}'),
            if (claim != null)
              FactRow(
                'You’ll be',
                '${g.personName(claim)}. Earlier payments confirmed by the owner stay unconfirmed by you.',
              ),
          ],
        ),
        primary: const ModalAction('Join group', value: true),
      );
      if (agreed != true) return false;
      await join(g, text.split('.')[1], name);
      return true;
    } on LocalRuleException catch (e) {
      setState(() {
        problem = sharedReason(e.message);
        command = newLocalId();
        joining = null;
        lost = false;
      });
    } catch (_) {
      setState(() => lost = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => CompactForm(
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
          SizedBox(height: CompactForm.fieldGap(context)),
        ],
        if (problem != null) ...[
          InlineNotice(problem!, tone: NoticeTone.error, live: true),
          SizedBox(height: CompactForm.fieldGap(context)),
        ],
        HelpTextField(
          key: const ValueKey('group-code'),
          label: 'Invitation code',
          controller: code,
          required: true,
          readOnly: lost,
          helper: 'Paste the whole code the owner shared with you.',
          errorText: codeError,
        ),
        SizedBox(height: CompactForm.fieldGap(context)),
        HelpTextField(
          key: const ValueKey('group-display'),
          label: 'Your name in this group',
          controller: display,
          required: true,
          readOnly: lost,
          errorText: displayError,
        ),
      ],
    ),
  );
}
