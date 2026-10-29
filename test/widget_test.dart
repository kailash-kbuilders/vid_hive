import 'package:flutter_test/flutter_test.dart';
import 'package:vid_hive/main.dart';

void main() {
  testWidgets('app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const VidHiveApp());
    expect(find.text('VidHive'), findsOneWidget);
  });
}
