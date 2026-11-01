import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/finance/finance_screen.dart';
import 'package:salapiya/finance/import_data.dart';
import 'package:salapiya/finance/import_flow.dart';
import 'package:salapiya/finance/money_editor.dart';
import 'package:salapiya/life/life_data.dart';
import 'package:salapiya/life/life_forms.dart';
import 'package:salapiya/profile/profile_actions.dart';
import 'package:salapiya/profile/profile_data.dart';
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
    'lib/life/life_controller.dart',
    'lib/local/local_profiles.dart',
    'lib/profile/profile_actions.dart',
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
      expect(found, hasLength(74));
      final mine = found.toSet().difference(internal);
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
      for (final message in internal) {
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

  group('connection and backup', () {
    const jargon = [
      'binding',
      'bound',
      'cloud history',
      'enrollment',
      'evidence',
      'identity',
      'integrity',
      'intent',
      'mismatch',
      'preserve',
      'publication',
      'receipt',
      'synchroniz',
    ];
    // Only a developer reaches these: the forms set what they're about.
    const internal = {
      'Wrong profile owner.',
      'This command ID already belongs to a different payload.',
      'Archive replay requires an empty, unconnected recovery database.',
      'Unsupported Life archive coverage.',
    };
    // Chat 15 rewords signing in.
    const signIn = {
      'Finish Google sign-in first.',
      'Select the Google identity bound to this profile.',
      'Reconnect with the Google identity already bound to this profile.',
      'This identity already owns a profile. Review the existing cloud profile.',
    };

    test('every message the section shows uses the glossary (§7)', () {
      for (final file in [
        'lib/connected/connected_runtime.dart',
        'lib/connected/connected_store.dart',
        'lib/local/local_store.dart',
      ]) {
        final source = File(file).readAsStringSync();
        final found = messages(source).toList();
        expect(found, isNotEmpty, reason: file);
        for (final message in found) {
          if (internal.contains(message) || signIn.contains(message)) continue;
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

    test('the sign-in messages left are still there for Chat 15', () {
      final source = [
        'lib/connected/connected_runtime.dart',
        'lib/connected/connected_store.dart',
      ].map((f) => File(f).readAsStringSync()).join();
      for (final message in signIn) {
        expect(source, contains(message));
      }
    });

    test('what Check a backup can reach is in plain words', () {
      final source = File('lib/local/local_profiles.dart').readAsStringSync();
      const words = [
        'Unsupported or incomplete',
        'Archive command history',
        'Archive counts',
        'local archive',
        'recovery graph',
        'attachment bytes',
      ];
      for (final word in words) {
        expect(source, isNot(contains(word)));
      }
    });

    test('the sync rule still starts as the forms expect', () {
      final store = File('lib/connected/connected_store.dart').readAsStringSync();
      final forms = File('lib/finance/form_mechanics.dart').readAsStringSync();
      final start = RegExp(r"startsWith\('([^']+)'\)").firstMatch(forms)![1]!;
      expect(store, contains(start));
    });

    test('every field word is still in a rule', () {
      for (final text in backupSecretErrors) {
        expect(rules, contains(text));
      }
    });

    test('every reason shown on Needs review is one that gets stored', () {
      final sql = Directory('../../services/salapiya/p0/supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('p2_'))
          .map((f) => f.readAsStringSync())
          .join();
      final stored = [
        sql,
        File('lib/connected/command_connector.dart').readAsStringSync(),
        File('lib/connected/connected_runtime.dart').readAsStringSync(),
        File('lib/local/local_profiles.dart').readAsStringSync(),
      ].join();
      for (final reason in changeReasons.keys) {
        final made = reason.startsWith('restored_')
            ? stored.contains(reason) || stored.contains('restored_\$')
            : stored.contains(reason);
        expect(made, isTrue, reason: reason);
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
