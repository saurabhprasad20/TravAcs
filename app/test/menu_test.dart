import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/core/theme/app_theme.dart';
import 'package:travacs/presentation/features/menu/app_menu_drawer.dart';

/// M13 app-menu drawer: renders all items, the dismiss (close) button works,
/// and it meets the tap-target + labelled-tap a11y guidelines.
void main() {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  Widget host() => ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        key: scaffoldKey,
        appBar: AppBar(title: const Text('Home')),
        drawer: const AppMenuDrawer(),
        body: const SizedBox.expand(),
      ),
    ),
  );

  testWidgets('shows every menu item', (tester) async {
    await tester.pumpWidget(host());
    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();

    for (final label in const [
      'Need help? Contact us',
      'About us',
      'Rate us on Play Store',
      'Terms & Conditions',
      'Privacy Policy',
      'Sign out',
      'Delete account',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'missing: $label');
    }
    // The dismiss button must carry a real semantic LABEL (not only a tooltip),
    // so TalkBack announces its name.
    expect(find.bySemanticsLabel('Close menu'), findsOneWidget);
  });

  testWidgets('the close button dismisses the drawer', (tester) async {
    await tester.pumpWidget(host());
    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);

    await tester.tap(find.byTooltip('Close menu'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsNothing); // drawer gone
  });

  testWidgets('delete account requires explicit confirmation', (tester) async {
    await tester.pumpWidget(host());
    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();

    final signOutTop = tester.getTopLeft(find.text('Sign out')).dy;
    final deleteTop = tester.getTopLeft(find.text('Delete account')).dy;
    expect(deleteTop, greaterThan(signOutTop));

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete account?'), findsOneWidget);
    expect(
      find.text(
        'Confirming will remove your user details and profile data from '
        'the app. This cannot be undone.',
      ),
      findsOneWidget,
    );
    expect(find.text('Keep account'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Delete account'), findsOneWidget);

    await tester.tap(find.text('Keep account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete account?'), findsNothing);
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('meets tap-target and labelled-tap guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(host());
      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      handle.dispose();
    }
  });
}
