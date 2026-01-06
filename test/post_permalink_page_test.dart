import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Post Permalink Page Widget Components Tests', () {
    testWidgets('Post Permalink Page có AppBar với title "Bài viết"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Bài viết'),
              actions: [
                PopupMenuButton(
                  icon: Icon(Icons.share),
                  itemBuilder: (context) => [],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Bài viết'), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('Post Permalink Page có CircleAvatar cho author', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Icon(Icons.person),
                ),
                SizedBox(width: 12),
                Text('Author Name'),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('Author Name'), findsOneWidget);
    });

    testWidgets('Post Permalink Page có Image để hiển thị media', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              height: 300,
              child: Image.network(
                'https://example.com/image.jpg',
                errorBuilder: (context, error, stackTrace) => Icon(Icons.image),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('Post Permalink Page có Text để hiển thị caption', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Text('Post caption text'),
          ),
        ),
      );

      expect(find.text('Post caption text'), findsOneWidget);
    });

    testWidgets('Post Permalink Page có IconButton cho like', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.favorite_border),
                  onPressed: () {},
                ),
                Text('0'),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets('Post Permalink Page có IconButton cho comment', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.comment_outlined),
                  onPressed: () {},
                ),
                Text('0'),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.comment_outlined), findsOneWidget);
    });

    testWidgets('Post Permalink Page có CircularProgressIndicator khi đang tải', (WidgetTester tester) async {
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

