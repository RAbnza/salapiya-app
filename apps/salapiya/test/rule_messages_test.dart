import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/finance/finance_screen.dart';
import 'package:salapiya/finance/import_data.dart';
import 'package:salapiya/finance/import_flow.dart';
import 'package:salapiya/finance/money_editor.dart';
import 'package:salapiya/shared/shared_data.dart';

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
