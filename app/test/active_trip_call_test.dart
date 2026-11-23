import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/core/theme/app_theme.dart';
import 'package:travacs/domain/entities/assignment.dart';
import 'package:travacs/domain/entities/city.dart';
import 'package:travacs/domain/entities/enums.dart';
import 'package:travacs/domain/entities/request.dart';
import 'package:travacs/presentation/features/requester/my_requests_screen.dart';
import 'package:travacs/presentation/features/shared/call_phone_button.dart';
import 'package:travacs/presentation/features/volunteer/my_trips_screen.dart';
import 'package:travacs/presentation/providers/core_providers.dart';
import 'package:travacs/presentation/providers/request_providers.dart';

void main() {
  late DateTime scheduledStart;
  late Assignment activeAssignment;
  late Request activeRequest;

  setUp(() {
    scheduledStart = DateTime.now().subtract(const Duration(hours: 1));
    activeAssignment = Assignment(
      requestId: 'request-1',
      volunteerId: 'travacser-1',
      volunteerName: 'Ravi',
      volunteerPhone: '+91 98765-43210',
      requesterId: 'user-1',
      requesterName: 'Asha',
      requesterPhone: '+91 (90000) 00000',
      scheduledDate: scheduledStart,
      startTime: '10:00',
      scheduledStartAt: scheduledStart,
      expectedDurationMinutes: 60,
      meetingPoint: 'Metro Gate 2',
      destination: 'Hospital',
      numTravellers: 1,
      amountInrEstimate: 249,
      tripStatus: TripStatus.started,
      startedAt: scheduledStart,
    );
    activeRequest = Request(
      id: 'request-1',
      requesterId: 'user-1',
      status: RequestStatus.started,
      serviceState: Region.delhiNcr,
      serviceCity: City.fromWire('delhi_ncr')!,
      numTravellers: 1,
      numTravAcsers: 1,
      genderPreference: GenderPreference.anyGender,
      scheduledDate: scheduledStart,
      startTime: '10:00',
      scheduledStartAt: scheduledStart,
      expectedDurationMinutes: 60,
      meetingPoint: 'Metro Gate 2',
      destination: 'Hospital',
      estimatedAmountInr: 249,
      acceptedCount: 1,
    );
  });

  testWidgets('call control opens a normalized tel URI and is accessible', (
    tester,
  ) async {
    Uri? launched;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneUriLauncherProvider.overrideWithValue((uri) async {
            launched = uri;
            return true;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: CallPhoneButton(
              contactRole: 'TravAcser',
              contactName: 'Ravi',
              phone: '+91 98765-43210',
            ),
          ),
        ),
      ),
    );

    final call = find.text('Call Ravi · +91 98765-43210');
    expect(call, findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Call TravAcser Ravi, phone + 9 1 9 8 7 6 5 4 3 2 1 0',
      ),
      findsOneWidget,
    );

    await tester.tap(call);
    await tester.pump();

    expect(launched, Uri(scheme: 'tel', path: '+919876543210'));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('failed dialler launch gives a useful copy fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneUriLauncherProvider.overrideWithValue((_) async => false),
          phoneClipboardWriterProvider.overrideWithValue((_) async {}),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CallPhoneButton(
              contactRole: 'User',
              contactName: 'Asha',
              phone: '+919000000000',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Call Asha · +919000000000'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text(
        'The phone app could not be opened. The phone number was copied.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('User can call the TravAcser from an active trip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Uri? launched;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myRequestsProvider.overrideWith(
            (ref) => Stream.value([activeRequest]),
          ),
          requestAssignmentsProvider(
            'request-1',
          ).overrideWith((ref) => Stream.value([activeAssignment])),
          clockProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          phoneUriLauncherProvider.overrideWithValue((uri) async {
            launched = uri;
            return true;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RequestDetailScreen(requestId: 'request-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final call = find.text('Call Ravi · +91 98765-43210');
    expect(call, findsOneWidget);
    await tester.tap(call);
    await tester.pump();

    expect(launched, Uri(scheme: 'tel', path: '+919876543210'));
  });

  testWidgets('TravAcser can call the User from an active trip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Uri? launched;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myAssignmentsProvider.overrideWith(
            (ref) => Stream.value([activeAssignment]),
          ),
          clockProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          phoneUriLauncherProvider.overrideWithValue((uri) async {
            launched = uri;
            return true;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MyTripsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final call = find.text('Call Asha · +91 (90000) 00000');
    expect(call, findsOneWidget);
    await tester.tap(call);
    await tester.pump();

    expect(launched, Uri(scheme: 'tel', path: '+919000000000'));
  });
}
