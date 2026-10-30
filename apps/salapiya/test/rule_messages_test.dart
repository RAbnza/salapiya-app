import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapiya/finance/finance_screen.dart';
import 'package:salapiya/finance/money_editor.dart';

/// The forms put a rule's message on its field by matching its words, and
/// people read those words, so these hold both to the rule files.
void main() {
  const files = [
    'lib/local/finance_domain.dart',
    'lib/finance/finance_rules.dart',
    'lib/finance/debt_rules.dart',
  ];
  final rules = files.map((f) => File(f).readAsStringSync()).join('\n');

  /// The text of every `reject(...)` in [source].
  Iterable<String> messages(String source) =>
      RegExp(r"reject\(\s*'([^']*)'").allMatches(source).map((m) => m[1]!);

  test('every word the forms match is still in a rule', () {
    for (final (text, field) in [...nativeRuleFields, ...moneyRuleFields]) {
      expect(rules, contains(text), reason: '$text, on $field');
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
