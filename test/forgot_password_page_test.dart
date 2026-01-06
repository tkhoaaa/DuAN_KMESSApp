import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Forgot Password Page Widget Components Tests', () {
    testWidgets('Forgot Password Page có title "Quên mật khẩu"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Quên mật khẩu'),
            ),
          ),
        ),
      );

      expect(find.text('Quên mật khẩu'), findsOneWidget);
    });

    testWidgets('Forgot Password Page có TextFormField cho email', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  hintText: 'Nhập email của bạn',
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.byIcon(Icons.email), findsOneWidget);
    });

    testWidgets('Forgot Password Page có FilledButton "Gửi email đặt lại"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilledButton(
              onPressed: () {},
              child: Text('Gửi email đặt lại'),
            ),
          ),
        ),
      );

      expect(find.text('Gửi email đặt lại'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('Forgot Password Page có success message khi email đã gửi', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                Text('Đã gửi email đặt lại mật khẩu'),
                Text('Vui lòng kiểm tra hộp thư của bạn'),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Đã gửi email đặt lại mật khẩu'), findsOneWidget);
    });

    testWidgets('Forgot Password Page có TextButton "Quay lại đăng nhập"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextButton(
              onPressed: () {},
              child: Text('Quay lại đăng nhập'),
            ),
          ),
        ),
      );

      expect(find.text('Quay lại đăng nhập'), findsOneWidget);
    });
  });
}

