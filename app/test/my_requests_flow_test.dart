import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/core/theme/app_theme.dart';
import 'package:travacs/domain/entities/assignment.dart';
import 'package:travacs/domain/entities/city.dart';
import 'package:travacs/domain/entities/enums.dart';
import 'package:travacs/domain/entities/request.dart';
import 'package:travacs/presentation/features/requester/my_requests_screen.dart';
import 'package:travacs/presentation/providers/core_providers.dart';
import 'package:travacs/presentation/providers/request_providers.dart';

/// Locks in the My Requests list → full-screen detail behaviour: the outer list
/// is a compact summary; the detail page exposes each label individually.
void main() {
  final sample = Request(
    id: 'r1',
    requesterId: 'u1',
    status: RequestStatus.broadcast, // active -> shown, label "Open"
    serviceState: Region.delhiNcr,
    serviceCity: City.fromWire('delhi_ncr')!,
    numTravellers: 2,
    numTravAcsers: 1,
    genderPreference: GenderPreference.anyGender,
    scheduledDate: DateTime(2026, 7, 1),
    startTime: '10:00',
    scheduledStartAt: DateTime(2026, 7, 1, 10, 0),
    expectedDurationMinutes: 120,
    meetingPoint: 'Connaught Place Metro Gate 2',
    destination: 'AIIMS OPD',
    estimatedAmountInr: 270,
    acceptedCount: 0, // no assignments -> no start-code stream needed
  );

  Widget app() => ProviderScope(
        overrides: [
          myRequestsProvider.overrideWith((ref) => Stream.value([sample])),
          // Non-periodic clock so pumpAndSettle doesn't hang on the 30s timer.
          clockProvider
              .overrideWith((ref) => Stream.value(DateTime(2026, 7, 1, 9, 0))),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MyRequestsScreen(),
        ),
      );

  testWidgets('outer list is a compact tile; tapping opens the detail page',
      (tester) async {
    // Tall surface so the detail's content (incl. bottom actions) all lays out
    // without needing to scroll a specific ListView.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      // Compact summary: date · time + a single-node status; NOT the per-label
      // detail rows yet.
      expect(find.textContaining('Jul 1, 2026'), findsOneWidget);
      expect(find.textContaining('10:00 AM'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('status Open')), findsOneWidget);
      expect(find.textContaining('Pick-up location'), findsNothing);

      // Open the detail page.
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Detail: AppBar + each field individually present and individually
      // labelled for a screen reader.
      expect(find.text('Trip details'), findsOneWidget);
      expect(find.textContaining('Pick-up location'), findsOneWidget);
      expect(find.textContaining('Destination'), findsOneWidget);
      expect(find.textContaining('Estimated amount'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Pick-up location: .*')),
          findsOneWidget);

      // Actions live inside the detail.
      expect(find.text('Cancel trip'), findsOneWidget);
      expect(find.text('Reschedule'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('each TravAcser\'s start code is labelled with their name',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // An active (assigned) 2-TravAcser trip with two accepted assignments.
    final assigned = Request(
      id: 'r1',
      requesterId: 'u1',
      status: RequestStatus.assigned,
      serviceState: Region.delhiNcr,
      serviceCity: City.fromWire('delhi_ncr')!,
      numTravellers: 2,
      numTravAcsers: 2,
      genderPreference: GenderPreference.anyGender,
      scheduledDate: DateTime(2026, 7, 1),
      startTime: '10:00',
      scheduledStartAt: DateTime(2026, 7, 1, 10, 0),
      expectedDurationMinutes: 120,
      meetingPoint: 'Connaught Place Metro Gate 2',
      destination: 'AIIMS OPD',
      estimatedAmountInr: 540,
      acceptedCount: 2,
    );
    Assignment tra(String id, String name, String phone) => Assignment(
          requestId: 'r1',
          volunteerId: id,
          volunteerName: name,
          volunteerPhone: phone,
          requesterId: 'u1',
          requesterName: 'Asha',
          requesterPhone: '+919000000000',
          scheduledDate: DateTime(2026, 7, 1),
          startTime: '10:00',
          scheduledStartAt: DateTime(2026, 7, 1, 10, 0),
          expectedDurationMinutes: 120,
          meetingPoint: 'Connaught Place Metro Gate 2',
          destination: 'AIIMS OPD',
          numTravellers: 2,
          amountInrEstimate: 398,
          tripStatus: TripStatus.assigned,
        );
    final assignments = [
      tra('v1', 'Ravi', '+919111111111'),
      tra('v2', 'Priya', '+919222222222'),
    ];

    Widget app() => ProviderScope(
          overrides: [
            myRequestsProvider.overrideWith((ref) => Stream.value([assigned])),
            requestAssignmentsProvider('r1')
                .overrideWith((ref) => Stream.value(assignments)),
            clockProvider.overrideWith(
                (ref) => Stream.value(DateTime(2026, 7, 1, 9, 0))),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const MyRequestsScreen(),
          ),
        );

    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Each code carries its TravAcser's name — visibly and for a screen
      // reader — so with two TravAcsers a blind User knows whose code is whose.
      expect(find.text('Start code for Ravi'), findsOneWidget);
      expect(find.text('Start code for Priya'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Start code for Ravi:.*')),
          findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Start code for Priya:.*')),
          findsOneWidget);
    } finally {
      handle.dispose();
    }
  });
}
