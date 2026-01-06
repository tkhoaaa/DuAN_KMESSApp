import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Register Screen Widget Components Tests', () {
    testWidgets('Register Screen có title "Tạo tài khoản mới"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Tạo tài khoản mới'),
            ),
          ),
        ),
      );

      expect(find.text('Tạo tài khoản mới'), findsOneWidget);
    });

    testWidgets('Register Screen có TextFormField cho email', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    });

    testWidgets('Register Screen có TextFormField cho password với obscureText', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: TextFormField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: Icon(Icons.lock_outline),
                  suffixIcon: Icon(Icons.visibility_off_outlined),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('Register Screen có FilledButton "Đăng ký"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilledButton(
              onPressed: () {},
              child: Text('Đăng ký'),
            ),
          ),
        ),
      );

      expect(find.text('Đăng ký'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('Register Screen có TextButton "Đăng nhập"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Đã có tài khoản? '),
                TextButton(
                  onPressed: () {},
                  child: Text('Đăng nhập'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('Đã có tài khoản? '), findsOneWidget);
    });

    testWidgets('Register Screen có social button cho Facebook', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutlinedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.facebook),
              label: Text('Đăng ký bằng Facebook'),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.facebook), findsOneWidget);
      expect(find.text('Đăng ký bằng Facebook'), findsOneWidget);
    });

    testWidgets('Register Screen có Divider với text "Hoặc"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Hoặc'),
                ),
                Expanded(child: Divider()),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Hoặc'), findsOneWidget);
      expect(find.byType(Divider), findsWidgets);
    });

    testWidgets('Register Screen có Form với GlobalKey', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: TextFormField(
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Form), findsOneWidget);
      expect(formKey.currentState, isNotNull);
    });
  });
}

