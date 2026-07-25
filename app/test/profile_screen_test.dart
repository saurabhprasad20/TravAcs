import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/core/theme/app_theme.dart';
import 'package:travacs/domain/entities/city.dart';
import 'package:travacs/domain/entities/enums.dart';
import 'package:travacs/domain/entities/profile.dart';
import 'package:travacs/presentation/features/profile/profile_tab_screen.dart';
import 'package:travacs/presentation/providers/profile_providers.dart';

/// Profile tab: gender is always shown (with a "Not set" fallback), and the
/// city/location row is announced only once for a screen reader.
void main() {
  final city = City.fromWire('delhi_ncr')!;

  MyProfile profile({Gender? gender}) => MyProfile(
        profile: Profile(
          id: 'u1',
          role: UserRole.requester,
          fullName: 'Asha',
          gender: gender,
          serviceArea: Region.delhiNcr,
          serviceCity: city,
          isActive: true,
        ),
        requester: const RequesterProfile(profileId: 'u1'),
      );

  Widget host(MyProfile p) => ProviderScope(
        overrides: [myProfileProvider.overrideWith((ref) async => p)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProfileTabScreen(),
        ),
      );

  testWidgets('shows "Not set" for a profile with no gender', (tester) async {
    await tester.pumpWidget(host(profile()));
    await tester.pumpAndSettle();
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
  });

  testWidgets('shows the gender label when set', (tester) async {
    await tester.pumpWidget(host(profile(gender: Gender.female)));
    await tester.pumpAndSettle();
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
  });

  testWidgets('city/location is announced only once (no double read)',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(host(profile()));
      await tester.pumpAndSettle();
      // The region row exposes exactly ONE node carrying the city/location, via
      // its excludeSemantics wrapper — the ListTile's own title/subtitle must
      // not add a second announcement.
      expect(
          find.bySemanticsLabel(RegExp('Your city / location:.*Delhi.*')),
          findsOneWidget);
      // The bare visible title text is excluded from the tree (no standalone
      // "Your city / location" node duplicating it).
      expect(find.bySemanticsLabel('Your city / location'), findsNothing);
    } finally {
      handle.dispose();
    }
  });
}
