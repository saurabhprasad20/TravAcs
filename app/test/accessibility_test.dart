import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/core/theme/app_theme.dart';
import 'package:travacs/domain/entities/city.dart';
import 'package:travacs/domain/entities/enums.dart';
import 'package:travacs/domain/entities/request.dart';
import 'package:travacs/presentation/features/shared/rating_sheet.dart';
import 'package:travacs/presentation/features/shared/request_card.dart';

/// M9 accessibility guarantees, locked in with `meetsGuideline` checks and
/// semantic-label assertions on the most-reused widgets. (The full
/// screen/integration suite is M10.)
void main() {
  final sample = Request(
    id: 'r1',
    requesterId: 'u1',
    status: RequestStatus.broadcast,
    serviceState: Region.delhiNcr,
    serviceCity: City.fromWire('delhi_ncr')!,
    numTravellers: 2,
    numTravAcsers: 1,
    numMaleTravellers: 1,
    numFemaleTravellers: 1,
    scheduledDate: DateTime(2026, 7, 1),
    startTime: '10:00',
    expectedDurationMinutes: 120,
    meetingPoint: 'Connaught Place Metro Gate 2',
    destination: 'AIIMS OPD',
    estimatedAmountInr: 270,
    acceptedCount: 0,
  );

  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      );

  /// Runs [body] with semantics enabled, disposing the handle even if an
  /// expectation throws (otherwise the leaked handle fails the next test).
  Future<void> withSemantics(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await body();
    } finally {
      handle.dispose();
    }
  }

  group('RequestCard', () {
    testWidgets('meets tap-target, labeled-tap and contrast guidelines',
        (tester) async {
      await withSemantics(tester, () async {
        await tester.pumpWidget(host(
          ListView(
            children: [
              RequestCard(
                request: sample,
                actions: [
                  TextButton(onPressed: () {}, child: const Text('Cancel')),
                ],
              ),
            ],
          ),
        ));

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });
    });

    testWidgets('status is exposed as a text label (not colour only)',
        (tester) async {
      await withSemantics(tester, () async {
        await tester.pumpWidget(host(RequestCard(request: sample)));
        // 'broadcast' renders as the user-facing label 'Open'.
        expect(find.bySemanticsLabel(RegExp('Status: Open')), findsOneWidget);
      });
    });

    testWidgets('the info block reads as one merged node', (tester) async {
      await withSemantics(tester, () async {
        await tester.pumpWidget(host(RequestCard(request: sample)));
        // The merged summary carries the route together with the rest.
        expect(find.bySemanticsLabel(RegExp('AIIMS OPD')), findsOneWidget);
      });
    });
  });

  group('Rating sheet', () {
    testWidgets('star buttons are labelled and meet tap-target size',
        (tester) async {
      await tester.pumpWidget(host(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showRatingSheet(context, title: 'Rate the User'),
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await withSemantics(tester, () async {
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('1 star'), findsOneWidget);
        expect(find.bySemanticsLabel('5 stars'), findsOneWidget);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      });
    });
  });
}
