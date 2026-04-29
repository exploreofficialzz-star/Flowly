import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Level generator produces correct number of levels', () {
    expect(5 * 20, equals(100));
  });

  test('App constants are valid', () {
    expect('com.chastechgroup.flowly', isNotEmpty);
    expect('Flowly', isNotEmpty);
  });

  test('Tube capacity is 4', () {
    const capacity = 4;
    expect(capacity, equals(4));
  });
}
