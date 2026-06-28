import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:travacs/core/theme/app_theme.dart';
import 'package:travacs/domain/repositories/auth_repository.dart';
import 'package:travacs/presentation/features/auth/otp_entry_screen.dart';
import 'package:travacs/presentation/features/shared/rating_sheet.dart';
import 'package:travacs/presentation/providers/auth_providers.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

/// Widget/flow tests (M10a): user-visible behaviour of the most logic-heavy
/// widgets, with Firebase mocked away.
void main() {
  Widget host(Widget child) =>
      MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child));

  group('Rating sheet', () {
    testWidgets('Submit is disabled until a star is chosen', (tester) async {
      await tester.pumpWidget(host(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showRatingSheet(context, title: 'Rate the User'),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      FilledButton submit() =>
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit rating'));
      expect(submit().onPressed, isNull); // gated

      await tester.tap(find.bySemanticsLabel('3 stars'));
      await tester.pump();
      expect(submit().onPressed, isNotNull); // enabled after a star
    });

    testWidgets('returns (stars, feedback) on submit', (tester) async {
      (int, String?)? result;
      await tester.pumpWidget(host(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showRatingSheet(context, title: 'Rate the User');
            },
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('4 stars'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Very helpful');
      await tester.tap(find.text('Submit rating'));
      await tester.pumpAndSettle();

      expect(result, (4, 'Very helpful'));
    });

    testWidgets('empty feedback comes back as null', (tester) async {
      (int, String?)? result;
      await tester.pumpWidget(host(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showRatingSheet(context, title: 'Rate the User');
            },
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('5 stars'));
      await tester.pump();
      await tester.tap(find.text('Submit rating'));
      await tester.pumpAndSettle();

      expect(result, (5, null));
    });
  });

  group('OtpEntryScreen', () {
    Widget otpHost(AuthRepository repo) => ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: OtpEntryScreen(phone: '+919999999999')),
        );

    testWidgets('rejects a short code without calling verifyOtp',
        (tester) async {
      final repo = _MockAuthRepo();
      await tester.pumpWidget(otpHost(repo));

      await tester.enterText(find.byType(TextFormField), '123');
      await tester.tap(find.text('Verify and continue'));
      await tester.pump();

      expect(find.text('Enter the 6-digit code'), findsOneWidget);
      verifyNever(() => repo.verifyOtp(
            verificationId: any(named: 'verificationId'),
            smsCode: any(named: 'smsCode'),
          ));
    });

    testWidgets('resend is disabled during the cooldown', (tester) async {
      await tester.pumpWidget(otpHost(_MockAuthRepo()));
      // Cooldown starts in initState; the button shows a countdown and is off.
      expect(find.textContaining('Resend code in'), findsOneWidget);
      final resend = tester.widget<TextButton>(
        find.ancestor(
          of: find.textContaining('Resend code in'),
          matching: find.byType(TextButton),
        ),
      );
      expect(resend.onPressed, isNull);
    });
  });
}
