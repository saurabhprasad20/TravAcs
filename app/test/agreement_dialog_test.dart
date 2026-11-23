import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/core/config/constants.dart';
import 'package:travacs/core/legal/legal_documents.dart';
import 'package:travacs/domain/entities/enums.dart';
import 'package:travacs/presentation/features/profile/agreement_dialog.dart';

void main() {
  test('each role maps to its hosted agreement', () {
    expect(
      LegalDocuments.agreementUrl(UserRole.requester),
      AppConstants.userAgreementUrl,
    );
    expect(
      LegalDocuments.agreementUrl(UserRole.volunteer),
      AppConstants.travAcserAgreementUrl,
    );
  });

  testWidgets(
    'registration shows a concise consent summary, not the document',
    (tester) async {
      await _openDialog(tester);

      expect(find.textContaining('By using TravAcs'), findsOneWidget);
      expect(
        find.text('Read User (TravAcsee) Agreement online'),
        findsOneWidget,
      );
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(find.textContaining('This User Agreement'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('uppercase name and explicit consent are both required', (
    tester,
  ) async {
    AgreementAcceptance? acceptance;
    await _openDialog(tester, onAccepted: (value) => acceptance = value);

    FilledButton continueButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );

    expect(continueButton().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Asha Rao');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(continueButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'ASHA RAO');
    await tester.pump();
    expect(continueButton().onPressed, isNotNull);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(acceptance?.role, UserRole.requester);
    expect(acceptance?.typedName, 'ASHA RAO');
  });

  testWidgets('changing role requires fresh consent for that agreement', (
    tester,
  ) async {
    await _openDialog(tester);
    await tester.enterText(find.byType(TextField), 'ASHA RAO');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();

    await tester.ensureVisible(find.text('TravAcser'));
    await tester.tap(find.text('TravAcser'));
    await tester.pumpAndSettle();

    expect(find.text('TravAcser Agreement'), findsOneWidget);
    expect(find.text('Read TravAcser Agreement online'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('compact consent dialog meets accessibility guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _openDialog(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
  });
}

Future<void> _openDialog(
  WidgetTester tester, {
  ValueChanged<AgreementAcceptance>? onAccepted,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder:
              (context) => FilledButton(
                onPressed: () async {
                  final value = await showAgreementDialog(
                    context,
                    initialRole: UserRole.requester,
                  );
                  onAccepted?.call(value);
                },
                child: const Text('Open agreement'),
              ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open agreement'));
  await tester.pumpAndSettle();
}
