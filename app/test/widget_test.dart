import 'package:flutter_test/flutter_test.dart';
import 'package:travacs/core/accessibility/announce.dart';

void main() {
  test('A11y.spellDigits spaces out digits for screen readers', () {
    expect(A11y.spellDigits('482107'), '4 8 2 1 0 7');
    expect(A11y.spellDigits(''), '');
  });
}
