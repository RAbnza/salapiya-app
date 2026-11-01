import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/finance/finance_screen.dart';
import 'package:salapiya/finance/import_data.dart';
import 'package:salapiya/finance/import_flow.dart';
import 'package:salapiya/finance/money_editor.dart';
import 'package:salapiya/life/life_data.dart';
import 'package:salapiya/life/life_forms.dart';
import 'package:salapiya/shared/shared_data.dart';
import 'package:salapiya/shared/shared_private_form.dart';

/// The forms put a rule's message on its field by matching its words, and
/// people read those words, so these hold both to the rule files.
void main() {
  const files = [
    'lib/local/finance_domain.dart',
    'lib/finance/finance_rules.dart',
    'lib/finance/debt_rules.dart',
    'lib/finance/card_rules.dart',
    'lib/finance/planning_rules.dart',
    'lib/finance/recurrence_rules.dart',
    'lib/finance/cash_import_rules.dart',
    'lib/shared/shared_private_domain.dart',
    'lib/life/life_domain.dart',
  ];
  final rules = files.map((f) => File(f).readAsStringSync()).join('\n');

  /// The text of every `reject(...)` in [source].
  Iterable<String> messages(String source) =>
      RegExp(r"reject\(\s*'([^']*)'").allMatches(source).map((m) => m[1]!);

  test('every word the forms match is still in a rule', () {
    for (final (text, field) in [
      ...nativeRuleFields,
      ...moneyRuleFields,
      ...importRuleFields,
      ...privateRuleFields,
      ...lifeRuleFields,
    ]) {
      expect(rules, contains(text), reason: '$text, on $field');
    }
  });

  test('Money’s messages use the glossary (§7)', () {
    const jargon = [
      'provider',
      'recognized',
      'liability',
      'evidence',
      'clearing',
      'allocation',
      'reservation',
      'occurrence',
      'recurrence',
      'bounded',
      'minor unit',
      'source revision',
    ];
    for (final file in [
      'lib/finance/card_rules.dart',
      'lib/finance/planning_rules.dart',
      'lib/finance/recurrence_rules.dart',
      'lib/finance/file_rules.dart',
      'lib/finance/file_store.dart',
    ]) {
      final found = messages(File(file).readAsStringSync()).toList();
      expect(found, isNotEmpty, reason: file);
      for (final message in found) {
        for (final word in jargon) {
          expect(
            message.toLowerCase(),
            isNot(contains(word)),
            reason: '$file: $message',
          );
        }
      }
    }
  });

  test(
    'the import’s refusals use the glossary, and its row notes don’t move',
    () {
      final source = File('lib/finance/cash_import_rules.dart')
          .readAsStringSync();
      const jargon = ['csv batch', 'staged', 'contract', 'preview', 'cutoff'];
      // Only a developer reaches these.
      const internal = {
        'Stage 1–16 bounded CSV rows within this batch.',
        'Use the original staged chunk identity.',
        'CSV staged rows overlap.',
        'Use the authorized atomic CSV opening transition.',
        'Disclose negative-balance consent explicitly.',
        'Invalid cash row classification, description or reference.',
      };
      for (final message in messages(source)) {
        if (internal.contains(message)) continue;
        for (final word in jargon) {
          expect(message.toLowerCase(), isNot(contains(word)), reason: message);
        }
      }
      // Stored in records and written by the server too, so only the screen
      // changes them.
      for (final stored in importRowNotes.keys) {
        expect(source, contains(stored));
      }
    },
  );

  test('the forecast’s messages and notes use the glossary (§7)', () {
    const jargon = [
      'provider',
      'evidence',
      'allocation',
      'hypothetical',
      'candidates',
      'contribution',
      'liability',
    ];
    final source = File('lib/finance/planning_queries.dart').readAsStringSync();
    final found = [
      ...messages(source),
      for (final m in RegExp(r"excluded\.add\(\s*'([^']*)'").allMatches(source))
        m[1]!,
    ];
    expect(found.length, greaterThan(14));
    for (final message in found) {
      for (final word in jargon) {
        expect(message.toLowerCase(), isNot(contains(word)), reason: message);
      }
    }
  });

  test('Shared Expenses’ messages use the glossary (§7)', () {
    const jargon = [
      'allocation',
      'axis',
      'capacity',
      'intent',
      'operation',
      'synchronize',
      'participants',
      'identity',
    ];
    // Only a developer reaches these.
    const internal = {
      'Use exact integer minor-unit strings.',
      'Positions do not sum to zero.',
      'Invalid authenticated group receipt.',
      'This command already has different frozen values.',
      'Unsupported shared storage version; preserve your database.',
    };
    for (final file in [
      'lib/shared/shared_domain.dart',
      'lib/shared/shared_repository.dart',
      'lib/shared/shared_store.dart',
    ]) {
      final found = messages(File(file).readAsStringSync()).toList();
      expect(found, isNotEmpty, reason: file);
      for (final message in found.where((m) => !internal.contains(m))) {
        for (final word in jargon) {
          expect(
            message.toLowerCase(),
            isNot(contains(word)),
            reason: '$file: $message',
          );
        }
      }
    }
  });

  test('the private forms’ messages use the glossary (§7)', () {
    const jargon = [
      'adopt',
      'allocation',
      'clearing',
      'coverage',
      'cutoff',
      'evidence',
      'funding',
      'immutable',
      'liability',
      'linkage',
      'noncash',
      'private',
      'reclassification',
      'reconcil',
      'revision',
    ];
    // Only a developer reaches these: the forms set what they're about.
    const internal = {
      'A versioned group source is required.',
      'Unsupported private group effect.',
      'Choose actual payment direction.',
      'Payment/refund cash corrections require their separate retained-evidence review.',
      'Unbalanced private group effect.',
    };
    final found = messages(
      File('lib/shared/shared_private_domain.dart').readAsStringSync(),
    ).toList();
    expect(found.toSet().length, 26);
    for (final message in found.where((m) => !internal.contains(m))) {
      for (final word in jargon) {
        expect(message.toLowerCase(), isNot(contains(word)), reason: message);
      }
    }
  });

  group('Life', () {
    /// The text of every `lifeReject(...)` in [source].
    Iterable<String> lifeMessages(String source) => RegExp(
      r"lifeReject\(\s*'([^']*)'",
    ).allMatches(source).map((m) => m[1]!);
    const lifeFiles = [
      'lib/life/life_domain.dart',
      'lib/life/life_controller.dart',
      'lib/life/device_reminders.dart',
      'lib/life/life_store.dart',
      'lib/life/career_documents.dart',
    ];
    // Only a developer reaches these: the forms set what they're about.
    const internal = {
      'Unsupported preset field.',
      'Invalid archive state.',
      'Choose a supported preset status.',
      'Choose a supported priority.',
      'Choose a supported event status.',
      'Choose a supported daylight-saving occurrence.',
      'UTC instant does not match the original timezone context.',
      'Invalid stable Life identity.',
      'Unsupported Life command contract.',
      'Life command must preserve its original canonical payload.',
      'Unsupported Life visibility preferences.',
      'Unsupported Life navigation preference.',
      'Unsupported Calendar visibility preference.',
      'Choose a supported reminder offset.',
      'Wrong private profile.',
      'Command ID reused with a changed payload.',
    };
    // Chat 13 rewords Learning, Books and Career's.
    const chat13 = {
      'Completion cannot precede the started date.',
      'Progress must be between zero and the positive total (at most 1,000,000).',
      'Rating must be an exact decimal from 0 to 5, with at most four decimal places.',
      'Rating must be between 0 and 5.',
      'Invalid bounded private Career document metadata.',
      'Choose a supported Career stage or outcome.',
      'Enter the company (at most 200 characters).',
      'Record the Career stage and distinct outcome explicitly.',
      'A saved opportunity is not submitted and has no application date.',
      'The stage date cannot precede submission.',
      'Choose a supported work arrangement.',
      'Choose a salary currency and period.',
      'Use a nonnegative exact salary value with at most two decimal places.',
      'Salary minimum exceeds maximum.',
      'Use an HTTP(S) posting URL without credentials.',
      'Choose a supported Career event kind.',
      'Interviews and assessments require a time and timezone.',
      'An observation is completed dated evidence, not an inferred outcome.',
      'Choose an active owned Career application.',
      'A Career event cannot move between attempts.',
      'Choose the current owned Career application.',
      'Document byte/source metadata is immutable. Select a new original for a new link.',
      'Career document metadata exceeds the 1,000 object / 1 GiB limit.',
      'A company/role match exists. Confirm a separate application attempt; valid reapplications are allowed.',
      'Choose valid progress on an active record.',
      'Protected file key unavailable.',
      'Private document/profile mismatch.',
      'Owned application unavailable.',
    };
    // Chat 14 rewords what a restore can reach.
    const chat14 = {
      'Unsupported Life archive coverage.',
      'Invalid Life archive history.',
      'Invalid original Life recovery intent.',
      'Invalid retained Life review decision.',
      'Invalid authenticated Life receipt.',
      'Reconnect with the bound identity.',
      'Recovery receipt identity mismatch.',
    };

    test('every message is reworded, or belongs to someone', () {
      const jargon = [
        'iana',
        'civil',
        'source',
        'generation',
        'endpoint',
        'native',
        'capacity',
        'intent',
        'evidence',
        'preserve',
        'protected',
        'workspace',
        'daylight',
        'reconcil',
      ];
      final found = [
        for (final file in lifeFiles)
          ...lifeMessages(File(file).readAsStringSync()),
      ];
      // Every call is counted once, so a new message can't slip by.
      expect(found, hasLength(72));
      final mine = found.toSet().difference({
        ...internal,
        ...chat13,
        ...chat14,
      });
      expect(mine, isNotEmpty);
      for (final message in mine) {
        for (final word in jargon) {
          expect(message.toLowerCase(), isNot(contains(word)), reason: message);
        }
      }
    });

    test('the lists above are all still rule messages', () {
      final found = {
        for (final file in lifeFiles)
          ...lifeMessages(File(file).readAsStringSync()),
      };
      for (final message in {...internal, ...chat13, ...chat14}) {
        expect(found, contains(message));
      }
    });

    test('a new phrase isn’t caught by an older one', () {
      for (final (i, (text, field)) in lifeRuleFields.indexed) {
        for (final (earlier, other) in lifeRuleFields.take(i)) {
          expect(
            text.contains(earlier) && field != other,
            isFalse,
            reason: '$text is caught by $earlier',
          );
        }
      }
    });

    test('every reason shown on screen is one that gets stored', () {
      final sql = Directory('../../services/salapiya/p0/supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('p5_'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      final stored = sql + File('lib/life/life_store.dart').readAsStringSync();
      for (final reason in lifeReasons.keys) {
        expect(stored, contains(reason), reason: reason);
      }
    });
  });

  test('every server reason shown on screen is one the server writes', () {
    final sql = Directory('../../services/salapiya/p0/supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('p3_'))
        .map((f) => f.readAsStringSync())
        .join('\n');
    for (final reason in sharedReasons.keys) {
      expect(sql, contains(reason), reason: reason);
    }
  });

  test('Debts messages use the glossary (§7)', () {
    const jargon = [
      'provider',
      'recognized',
      'liability',
      'evidence',
      'clearing',
      'installment',
      'reconcile',
      'contractual',
      'allocation',
    ];
    final debts = File('lib/finance/debt_rules.dart').readAsStringSync();
    final found = messages(debts).toList();
    expect(found.length, greaterThan(40));
    for (final message in found) {
      for (final word in jargon) {
        expect(message.toLowerCase(), isNot(contains(word)), reason: message);
      }
    }
  });
}
