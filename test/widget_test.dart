import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/main.dart';

void main() {
  testWidgets('login page shows key actions', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('邮箱'), findsOneWidget);
    expect(find.text('手机号'), findsOneWidget);
    expect(find.text('登录并进入市场'), findsOneWidget);
    expect(find.text('使用 Google 继续'), findsOneWidget);
  });
}
