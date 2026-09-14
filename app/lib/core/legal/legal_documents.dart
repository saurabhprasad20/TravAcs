import '../../domain/entities/enums.dart';

abstract final class LegalDocuments {
  static const agreementPartCount = 5;
  static const agreementVersion = '2026-08-06';
  static const termsAsset = 'assets/legal/terms_and_conditions.txt';
  static const privacyAsset = 'assets/legal/privacy_policy.txt';
  static const userAgreementAsset = 'assets/legal/user_agreement.txt';
  static const travAcserAgreementAsset = 'assets/legal/travacser_agreement.txt';

  static String agreementAsset(UserRole role) =>
      role == UserRole.volunteer ? travAcserAgreementAsset : userAgreementAsset;

  static String agreementTitle(UserRole role) =>
      role == UserRole.volunteer
          ? 'TravAcser Agreement'
          : 'User (TravAcsee) Agreement';

  /// Splits a long agreement into similarly sized, separately focusable parts.
  /// Whole source lines stay together so numbered clauses are not cut in half.
  static List<String> agreementParts(String text) {
    final paragraphs =
        text
            .replaceAll('\r\n', '\n')
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
    if (paragraphs.length <= agreementPartCount) return paragraphs;

    int wordsIn(String value) => RegExp(r'\S+').allMatches(value).length;

    final parts = <String>[];
    var nextParagraph = 0;
    var remainingWords = paragraphs.fold<int>(
      0,
      (total, paragraph) => total + wordsIn(paragraph),
    );

    for (var partIndex = 0; partIndex < agreementPartCount - 1; partIndex++) {
      final remainingParts = agreementPartCount - partIndex;
      final targetWords = remainingWords / remainingParts;
      final partParagraphs = <String>[];
      var partWords = 0;

      while (nextParagraph < paragraphs.length - (remainingParts - 1)) {
        final paragraph = paragraphs[nextParagraph];
        final paragraphWords = wordsIn(paragraph);
        final currentDifference = (targetWords - partWords).abs();
        final addedDifference =
            (targetWords - (partWords + paragraphWords)).abs();
        if (partParagraphs.isNotEmpty && addedDifference > currentDifference) {
          break;
        }
        partParagraphs.add(paragraph);
        partWords += paragraphWords;
        nextParagraph++;
      }

      parts.add(partParagraphs.join('\n\n'));
      remainingWords -= partWords;
    }

    parts.add(paragraphs.sublist(nextParagraph).join('\n\n'));
    return parts;
  }
}

class AgreementAcceptance {
  const AgreementAcceptance({required this.role, required this.typedName});

  final UserRole role;
  final String typedName;
}
