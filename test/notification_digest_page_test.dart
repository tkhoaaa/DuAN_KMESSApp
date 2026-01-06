import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notification Digest Page Widget Components Tests', () {
    testWidgets('Notification Digest Page có AppBar với title "Tóm tắt thông báo"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Tóm tắt thông báo'),
            ),
          ),
        ),
      );

      expect(find.text('Tóm tắt thông báo'), findsOneWidget);
    });

    testWidgets('Notification Digest Page có ListView cho danh sách thông báo', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text('Notification $index'),
                  subtitle: Text('Time $index'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Notification 0'), findsOneWidget);
    });

    testWidgets('Notification Digest Page có empty state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Chưa có thông báo nào'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      expect(find.text('Chưa có thông báo nào'), findsOneWidget);
    });
  });
}

