import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haoka_app/main.dart';

void main() {
  testWidgets('brand appears on splash', (tester) async {
    await tester.pumpWidget(const HaokaApp());
    expect(find.text('派客邦'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
