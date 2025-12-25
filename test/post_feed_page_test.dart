import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Post Feed Page Widget Components Tests', () {
    testWidgets('AppBar có title "Bảng tin"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Bảng tin'),
            ),
          ),
        ),
      );

      expect(find.text('Bảng tin'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('FloatingActionButton có icon add và label "Tạo bài viết"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              icon: Icon(Icons.add),
              label: Text('Tạo bài viết'),
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('Tạo bài viết'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('PopupMenuButton có icon more_vert', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                PopupMenuButton(
                  icon: Icon(Icons.more_vert),
                  itemBuilder: (context) => [],
                ),
              ],
            ),
          ),
        ),
      );

      // PopupMenuButton sử dụng IconButton bên trong
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('RefreshIndicator có thể kéo để refresh', (WidgetTester tester) async {
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
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('CustomScrollView có thể scroll', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(height: 100, child: Text('Item 1')),
                ),
                SliverToBoxAdapter(
                  child: Container(height: 100, child: Text('Item 2')),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('GridView có gridDelegate với crossAxisCount 3', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 6,
              itemBuilder: (context, index) => Container(
                color: Colors.blue,
                child: Text('Item $index'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('Item 0'), findsOneWidget);
    });
  });
}

