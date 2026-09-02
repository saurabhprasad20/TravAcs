import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/core/config/constants.dart';
import 'package:travacs/core/theme/app_theme.dart';
import 'package:travacs/presentation/features/menu/info_screens.dart';

/// The drawer info screens carry real, finalised content (no placeholder
/// banners) and the correct support details.
void main() {
  Widget host(Widget screen) =>
      MaterialApp(theme: AppTheme.light(), home: screen);

  test('public policy URLs use the owned Firebase Hosting site', () {
    expect(
      AppConstants.termsUrl,
      'https://travacs-dev.web.app/termsandconditions',
    );
    expect(
      AppConstants.privacyPolicyUrl,
      'https://travacs-dev.web.app/privacypolicies',
    );
    expect(
      AppConstants.accountDeletionUrl,
      'https://travacs-dev.web.app/accountdeletion',
    );
  });

  testWidgets(
    'Contact us shows the real support details, no placeholder note',
    (tester) async {
      await tester.pumpWidget(host(const ContactUsScreen()));
      await tester.pumpAndSettle();
      expect(find.text(AppConstants.supportEmail), findsOneWidget);
      expect(find.text(AppConstants.supportPhone), findsOneWidget);
      expect(find.text(AppConstants.website), findsOneWidget);
      expect(find.textContaining('placeholder'), findsNothing);
      // Rows are actionable (call / email / open website) — not copy buttons.
      expect(
        find.bySemanticsLabel('Call Phone, ${AppConstants.supportPhone}'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Email Email, ${AppConstants.supportEmail}'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Open Website, ${AppConstants.website}'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.copy_outlined), findsNothing);
    },
  );

  testWidgets('Terms shows real sections and no draft banner', (tester) async {
    await tester.pumpWidget(host(const TermsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Terms & Conditions'), findsOneWidget);
    expect(find.textContaining('Draft'), findsNothing);
    expect(find.textContaining('placeholder'), findsNothing);
    expect(find.textContaining('TravAcs Welfare Foundation'), findsOneWidget);
    expect(
      find.textContaining('PAYMENTS, PRICING AND FINANCIAL'),
      findsOneWidget,
    );
  });

  testWidgets('Privacy shows real sections and no draft banner', (
    tester,
  ) async {
    await tester.pumpWidget(host(const PrivacyPolicyScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.textContaining('INFORMATION WE COLLECT'), findsOneWidget);
    expect(find.textContaining('Draft'), findsNothing);
    expect(find.textContaining('placeholder'), findsNothing);
  });
}
