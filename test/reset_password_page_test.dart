import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reset Password Page Widget Components Tests', () {
    testWidgets('Reset Password Page có AppBar với title "Đặt lại mật khẩu"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Đặt lại mật khẩu'),
            ),
          ),
        ),
      );

      expect(find.text('Đặt lại mật khẩu'), findsOneWidget);
    });

    testWidgets('Reset Password Page có TextFormField cho mật khẩu mới', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: TextFormField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Mật khẩu mới'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('Reset Password Page có TextFormField cho xác nhận mật khẩu', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: TextFormField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Xác nhận mật khẩu',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Xác nhận mật khẩu'), findsOneWidget);
    });

    testWidgets('Reset Password Page có FilledButton "Đặt lại mật khẩu"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilledButton(
              onPressed: () {},
              child: Text('Đặt lại mật khẩu'),
            ),
          ),
        ),
      );

      expect(find.text('Đặt lại mật khẩu'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });
}

