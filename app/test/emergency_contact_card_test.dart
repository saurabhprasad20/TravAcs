import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/presentation/features/profile/emergency_contact_card.dart';

void main() {
  late TextEditingController name;
  late TextEditingController relation;
  late TextEditingController phone;

  setUp(() {
    name = TextEditingController();
    relation = TextEditingController();
    phone = TextEditingController();
  });

  tearDown(() {
    name.dispose();
    relation.dispose();
    phone.dispose();
  });

  Widget host({GlobalKey<FormState>? formKey, VoidCallback? onSave}) =>
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: EmergencyContactCard(
              nameController: name,
              relationController: relation,
              phoneController: phone,
              onSave: onSave,
            ),
          ),
        ),
      );

  testWidgets('is collapsed and optional by default', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('Emergency contact (optional)'), findsOneWidget);
    expect(find.text('You can provide it later.'), findsOneWidget);
    expect(find.byKey(const ValueKey('emergency-contact-name')), findsNothing);

    await tester.tap(find.text('Emergency contact (optional)'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('emergency-contact-name')),
      findsOneWidget,
    );
  });

  testWidgets('requires all fields after the contact is started', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      host(formKey: formKey, onSave: () => formKey.currentState!.validate()),
    );
    await tester.tap(find.text('Emergency contact (optional)'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('emergency-contact-name')),
      'Ravi',
    );
    await tester.tap(find.text('Save emergency contact'));
    await tester.pump();

    expect(
      find.text('Please enter the emergency contact relation'),
      findsOneWidget,
    );
    expect(
      find.text('Please enter the emergency contact phone number'),
      findsOneWidget,
    );
  });

  testWidgets('phone field accepts digits only', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Emergency contact (optional)'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('emergency-contact-phone')),
      '+91 98ab76',
    );
    expect(phone.text, '919876');
  });

  testWidgets('failed validation can reopen a collapsed partial contact', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final expansionController = ExpansionTileController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: Column(
              children: [
                EmergencyContactCard(
                  nameController: name,
                  relationController: relation,
                  phoneController: phone,
                  expansionController: expansionController,
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      expansionController.expand();
                    }
                  },
                  child: const Text('Create profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Emergency contact (optional)'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('emergency-contact-name')),
      'Ravi',
    );
    await tester.tap(find.text('Emergency contact (optional)'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('emergency-contact-relation')),
      findsNothing,
    );

    await tester.tap(find.text('Create profile'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('emergency-contact-relation')),
      findsOneWidget,
    );
    expect(
      find.text('Please enter the emergency contact relation'),
      findsOneWidget,
    );
  });
}
