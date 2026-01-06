import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Privacy Settings Page Widget Components Tests', () {
    testWidgets('Privacy Settings Page có AppBar với title "Cài đặt quyền riêng tư"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Cài đặt quyền riêng tư'),
            ),
          ),
        ),
      );

      expect(find.text('Cài đặt quyền riêng tư'), findsOneWidget);
    });

    testWidgets('Privacy Settings Page có SwitchListTile cho tài khoản riêng tư', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwitchListTile(
              title: Text('Tài khoản riêng tư'),
              subtitle: Text('Chỉ người theo dõi mới thấy bài viết của bạn'),
              value: false,
              onChanged: (value) {},
            ),
          ),
        ),
      );

      expect(find.text('Tài khoản riêng tư'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('Privacy Settings Page có ListTile cho chặn người dùng', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              leading: Icon(Icons.block),
              title: Text('Người dùng đã chặn'),
              trailing: Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Người dùng đã chặn'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });

    testWidgets('Privacy Settings Page có ListTile cho quản lý follow requests', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              leading: Icon(Icons.person_add),
              title: Text('Yêu cầu theo dõi'),
              trailing: Badge(
                child: Text('5'),
              ),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Yêu cầu theo dõi'), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
    });
  });
}

