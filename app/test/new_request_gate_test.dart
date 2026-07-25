import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/core/theme/app_theme.dart';
import 'package:travacs/domain/entities/city.dart';
import 'package:travacs/domain/entities/enums.dart';
import 'package:travacs/domain/entities/profile.dart';
import 'package:travacs/domain/entities/request.dart';
import 'package:travacs/presentation/features/requester/new_request_screen.dart';
import 'package:travacs/presentation/providers/profile_providers.dart';
import 'package:travacs/presentation/providers/request_providers.dart';

/// Item 3/4/5: the New Request wizard is blocked (never rendered) while the User
/// has a trip in progress or a completed trip awaiting payment.
void main() {
  final city = City.fromWire('delhi_ncr')!;

  MyProfile myProfile() => MyProfile(
        profile: Profile(
          id: 'u1',
          role: UserRole.requester,
          fullName: 'Asha',
          serviceArea: Region.delhiNcr,
          serviceCity: city,
          isActive: true,
        ),
      );

  Request req(String id, RequestStatus status,
          {int? tripAmountInr, DateTime? paidAt}) =>
      Request(
        id: id,
        requesterId: 'u1',
        status: status,
        serviceState: Region.delhiNcr,
        serviceCity: city,
        numTravellers: 1,
        numTravAcsers: 1,
        genderPreference: GenderPreference.anyGender,
        scheduledDate: DateTime.now().add(const Duration(hours: 2)),
        startTime: '10:00',
        scheduledStartAt: DateTime.now().add(const Duration(hours: 2)),
        expectedDurationMinutes: 60,
        meetingPoint: 'A',
        destination: 'B',
        estimatedAmountInr: 135,
        tripAmountInr: tripAmountInr,
        requesterPaidAt: paidAt,
      );

  Widget app(List<Request> requests) => ProviderScope(
        overrides: [
          myProfileProvider.overrideWith((ref) async => myProfile()),
          myRequestsProvider.overrideWith((ref) => Stream.value(requests)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const NewRequestScreen(),
        ),
      );

  testWidgets('blocks the form while a trip is in progress', (tester) async {
    await tester.pumpWidget(app([req('r1', RequestStatus.started)]));
    await tester.pumpAndSettle();
    expect(find.text('A trip is in progress'), findsOneWidget);
    // The form (its first field) must NOT be present.
    expect(find.text('Meeting point with the TravAcser'), findsNothing);
  });

  testWidgets('blocks the form while a payment is pending', (tester) async {
    await tester.pumpWidget(app([
      req('r1', RequestStatus.completed, tripAmountInr: 415),
    ]));
    await tester.pumpAndSettle();
    // The title must appear exactly ONCE (the icon must not duplicate it for
    // screen readers).
    expect(find.text('Payment pending'), findsOneWidget);
    expect(find.text('Meeting point with the TravAcser'), findsNothing);
  });

  testWidgets('shows the form when there is no active/unpaid trip',
      (tester) async {
    await tester.pumpWidget(app([
      // a paid completed trip does not block
      req('r1', RequestStatus.completed,
          tripAmountInr: 415, paidAt: DateTime.now()),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('A trip is in progress'), findsNothing);
    expect(find.text('Payment pending'), findsNothing);
    expect(find.text('Meeting point with the TravAcser'), findsOneWidget);
    // Item 8: expected duration is a slider (default 1 hour).
    expect(find.byType(Slider), findsOneWidget);
    expect(find.textContaining('Expected duration: 1 hour'), findsOneWidget);
  });

  testWidgets('shows a loader (not the form) while requests are still loading',
      (tester) async {
    // A stream that never emits keeps myRequestsProvider in the loading state.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myProfileProvider.overrideWith((ref) async => myProfile()),
          myRequestsProvider.overrideWith(
              (ref) => Stream<List<Request>>.fromFuture(
                  Completer<List<Request>>().future)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const NewRequestScreen(),
        ),
      ),
    );
    await tester.pump(); // let the profile future resolve
    // The form must NOT render until we know the trip state.
    expect(find.text('Meeting point with the TravAcser'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });
}
