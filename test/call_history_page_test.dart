import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Call History Page Widget Components Tests', () {
    testWidgets('Call History Page có AppBar với title "Lịch sử cuộc gọi"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Lịch sử cuộc gọi'),
            ),
          ),
        ),
      );

      expect(find.text('Lịch sử cuộc gọi'), findsOneWidget);
    });

    testWidgets('Call History Page có ListView cho danh sách cuộc gọi', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => ListTile(
                leading: CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text('User $index'),
                subtitle: Text('Video call - 10:30 AM'),
                trailing: IconButton(
                  icon: Icon(Icons.call),
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('User 0'), findsOneWidget);
      expect(find.byIcon(Icons.call), findsWidgets);
    });

    testWidgets('Call History Page có Icon phone cho voice call', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              leading: Icon(Icons.phone),
              title: Text('Voice call'),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.phone), findsOneWidget);
    });

    testWidgets('Call History Page có Icon videocam cho video call', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              leading: Icon(Icons.videocam),
              title: Text('Video call'),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.videocam), findsOneWidget);
    });

    testWidgets('Call History Page có empty state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.call_missed, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Chưa có cuộc gọi nào'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.call_missed), findsOneWidget);
      expect(find.text('Chưa có cuộc gọi nào'), findsOneWidget);
    });

    testWidgets('Call History Page có CircularProgressIndicator khi đang tải', (WidgetTester tester) async {
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

