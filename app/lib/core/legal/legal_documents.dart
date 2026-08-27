import '../../domain/entities/enums.dart';

abstract final class LegalDocuments {
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
}

class AgreementAcceptance {
  const AgreementAcceptance({required this.role, required this.typedName});

  final UserRole role;
  final String typedName;
}
