import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_manager/data/services/storage_service.dart';
import 'package:inventory_manager/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();

    await tester.pumpWidget(RoboticsInventoryApp(storageService: storageService));
    expect(find.byType(RoboticsInventoryApp), findsOneWidget);
  });
}
