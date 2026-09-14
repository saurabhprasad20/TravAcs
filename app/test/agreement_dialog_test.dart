import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/core/legal/legal_documents.dart';
import 'package:travacs/presentation/features/profile/agreement_dialog.dart';

void main() {
  const sampleParagraphs = [
    'One two three four five six seven eight nine ten.',
    'Eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen.',
    'Nineteen twenty twenty-one twenty-two twenty-three twenty-four.',
    'Twenty-five twenty-six twenty-seven twenty-eight twenty-nine thirty.',
    'Thirty-one thirty-two thirty-three thirty-four thirty-five thirty-six.',
    'Thirty-seven thirty-eight thirty-nine forty forty-one forty-two.',
    'Forty-three forty-four forty-five forty-six forty-seven forty-eight.',
    'Forty-nine fifty fifty-one fifty-two fifty-three fifty-four.',
    'Fifty-five fifty-six fifty-seven fifty-eight fifty-nine sixty.',
    'Sixty-one sixty-two sixty-three sixty-four sixty-five sixty-six.',
  ];
  final sampleText = sampleParagraphs.join('\n');

  test('agreement text is split into five balanced parts', () {
    final parts = LegalDocuments.agreementParts(sampleText);
    expect(parts, hasLength(LegalDocuments.agreementPartCount));

    final wordCounts =
        parts.map((part) => RegExp(r'\S+').allMatches(part).length).toList();
    final smallest = wordCounts.reduce((a, b) => a < b ? a : b);
    final largest = wordCounts.reduce((a, b) => a > b ? a : b);
    expect(largest - smallest, lessThanOrEqualTo(10));

    for (final paragraph in sampleParagraphs) {
      expect(
        parts.where((part) => part.contains(paragraph)),
        hasLength(1),
        reason: 'paragraph must stay intact: $paragraph',
      );
    }
  });

  for (final asset in [
    LegalDocuments.userAgreementAsset,
    LegalDocuments.travAcserAgreementAsset,
  ]) {
    test('$asset is preserved in five balanced parts', () {
      final text = File(asset).readAsStringSync();
      final parts = LegalDocuments.agreementParts(text);
      expect(parts, hasLength(LegalDocuments.agreementPartCount));
      expect(parts, everyElement(isNotEmpty));

      final sourceParagraphs =
          text
              .replaceAll('\r\n', '\n')
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList();
      final rebuiltParagraphs =
          parts.expand((part) => part.split('\n\n')).toList();
      expect(rebuiltParagraphs, sourceParagraphs);

      final counts =
          parts.map((part) => RegExp(r'\S+').allMatches(part).length).toList();
      final average = counts.reduce((a, b) => a + b) / counts.length;
      for (final count in counts) {
        expect(
          (count - average).abs() / average,
          lessThan(0.08),
          reason: 'word counts should be within 8% of the average: $counts',
        );
      }
    });
  }

  testWidgets('agreement exposes five separately focusable reading parts', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: AgreementTextView(
                title: 'User Agreement',
                text: sampleText,
              ),
            ),
          ),
        ),
      );

      for (var part = 1; part <= LegalDocuments.agreementPartCount; part++) {
        expect(find.byKey(ValueKey('agreement-part-$part')), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('User Agreement, part $part of 5\\.')),
          findsOneWidget,
        );
      }
    } finally {
      semantics.dispose();
    }
  });
}
