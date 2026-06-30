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
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'missing: $label');
    }
    expect(find.byTooltip('Close menu'), findsOneWidget);
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
