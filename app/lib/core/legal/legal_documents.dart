import '../../domain/entities/enums.dart';
import '../config/constants.dart';

abstract final class LegalDocuments {
  static const agreementVersion = '2026-08-06';
  static const termsAsset = 'assets/legal/terms_and_conditions.txt';
  static const privacyAsset = 'assets/legal/privacy_policy.txt';

  static String agreementTitle(UserRole role) =>
      role == UserRole.volunteer
          ? 'TravAcser Agreement'
          : 'User (TravAcsee) Agreement';

  static String agreementUrl(UserRole role) =>
      role == UserRole.volunteer
          ? AppConstants.travAcserAgreementUrl
          : AppConstants.userAgreementUrl;
}

class AgreementAcceptance {
  const AgreementAcceptance({required this.role, required this.typedName});

  final UserRole role;
  final String typedName;
}
