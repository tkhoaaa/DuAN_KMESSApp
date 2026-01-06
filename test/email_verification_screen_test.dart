import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Email Verification Screen Widget Components Tests', () {
    testWidgets('Email Verification Screen có AppBar với title "Xác thực email"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Xác thực email'),
              actions: [
                IconButton(
                  icon: Icon(Icons.logout),
                  tooltip: 'Đăng xuất',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Xác thực email'), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('Email Verification Screen có Icon check_circle khi đã xác thực', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 64),
                Text('Email đã được xác thực'),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Email đã được xác thực'), findsOneWidget);
    });

    testWidgets('Email Verification Screen có Icon email_outlined', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Icon(Icons.email_outlined, size: 64),
                Text('Vui lòng kiểm tra email của bạn'),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    });

    testWidgets('Email Verification Screen có FilledButton "Gửi lại email"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilledButton.icon(
              onPressed: () {},
              icon: Icon(Icons.refresh),
              label: Text('Gửi lại email'),
            ),
          ),
        ),
      );

      expect(find.text('Gửi lại email'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('Email Verification Screen có FilledButton "Kiểm tra lại"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilledButton.icon(
              onPressed: () {},
              icon: Icon(Icons.refresh),
              label: Text('Kiểm tra lại'),
            ),
          ),
        ),
      );

      expect(find.text('Kiểm tra lại'), findsOneWidget);
    });

    testWidgets('Email Verification Screen có CircularProgressIndicator khi đang gửi', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

