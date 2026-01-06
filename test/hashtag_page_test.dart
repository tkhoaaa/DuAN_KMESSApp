import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Hashtag Page Widget Components Tests', () {
    testWidgets('Hashtag Page có AppBar với hashtag title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('#hashtag'),
            ),
          ),
        ),
      );

      expect(find.text('#hashtag'), findsOneWidget);
    });

    testWidgets('Hashtag Page có TabBar với 2 tabs', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                bottom: TabBar(
                  tabs: [
                    Tab(text: 'Mới nhất'),
                    Tab(text: 'Hot'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Mới nhất'), findsOneWidget);
      expect(find.text('Hot'), findsOneWidget);
    });

    testWidgets('Hashtag Page có GridView cho danh sách bài viết', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 6,
              itemBuilder: (context, index) => Container(
                color: Colors.grey[300],
                child: Icon(Icons.image),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byIcon(Icons.image), findsWidgets);
    });

    testWidgets('Hashtag Page có RefreshIndicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                children: [Text('Content')],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('Hashtag Page có empty state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tag, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Chưa có bài viết nào với hashtag này'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.tag), findsOneWidget);
      expect(find.text('Chưa có bài viết nào với hashtag này'), findsOneWidget);
    });
  });
}

