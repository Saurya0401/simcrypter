import 'package:flutter_test/flutter_test.dart';

import 'package:simcrypter/main.dart';

void main() {
  testWidgets('Basic Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(SimcrypterApp());
  });
}
