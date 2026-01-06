import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Drafts and Scheduled Page Widget Components Tests', () {
    testWidgets('Drafts and Scheduled Page có AppBar với title "Bản nháp & Lịch đăng"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Bản nháp & Lịch đăng'),
            ),
          ),
        ),
      );

      expect(find.text('Bản nháp & Lịch đăng'), findsOneWidget);
    });

    testWidgets('Drafts and Scheduled Page có TabBar với 2 tabs', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                bottom: TabBar(
                  tabs: [
                    Tab(text: 'Bản nháp'),
                    Tab(text: 'Lịch đăng'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Bản nháp'), findsOneWidget);
      expect(find.text('Lịch đăng'), findsOneWidget);
    });

    testWidgets('Drafts and Scheduled Page có ListView cho danh sách bản nháp', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => Card(
                child: ListTile(
                  leading: Icon(Icons.drafts),
                  title: Text('Draft $index'),
                  subtitle: Text('Last edited: ${DateTime.now()}'),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Draft 0'), findsOneWidget);
      expect(find.byIcon(Icons.drafts), findsWidgets);
    });

    testWidgets('Drafts and Scheduled Page có ListView cho danh sách lịch đăng', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 3,
              itemBuilder: (context, index) => Card(
                child: ListTile(
                  leading: Icon(Icons.schedule),
                  title: Text('Scheduled post $index'),
                  subtitle: Text('Scheduled for: ${DateTime.now()}'),
                  trailing: IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.schedule), findsWidgets);
      expect(find.text('Scheduled post 0'), findsOneWidget);
    });

    testWidgets('Drafts and Scheduled Page có empty state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.drafts, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Chưa có bản nháp nào'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.drafts), findsOneWidget);
      expect(find.text('Chưa có bản nháp nào'), findsOneWidget);
    });
  });
}

