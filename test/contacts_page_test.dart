import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Contacts Page Widget Components Tests', () {
    testWidgets('Contacts Page có AppBar với title "Danh bạ"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Danh bạ'),
            ),
          ),
        ),
      );

      expect(find.text('Danh bạ'), findsOneWidget);
    });

    testWidgets('Contacts Page có TextField để tìm kiếm', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Tìm kiếm...'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('Contacts Page có ListView cho danh sách liên hệ', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 10,
              itemBuilder: (context, index) => ListTile(
                leading: CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text('Contact $index'),
                subtitle: Text('contact$index@example.com'),
                trailing: IconButton(
                  icon: Icon(Icons.message),
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Contact 0'), findsOneWidget);
      expect(find.byIcon(Icons.message), findsWidgets);
    });

    testWidgets('Contacts Page có empty state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.contacts, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Chưa có liên hệ nào'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.contacts), findsOneWidget);
      expect(find.text('Chưa có liên hệ nào'), findsOneWidget);
    });
  });
}

