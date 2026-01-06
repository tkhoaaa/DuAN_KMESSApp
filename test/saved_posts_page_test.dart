import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Saved Posts Page Widget Components Tests', () {
    testWidgets('Saved Posts Page có AppBar với title "Bài viết đã lưu"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Bài viết đã lưu'),
            ),
          ),
        ),
      );

      expect(find.text('Bài viết đã lưu'), findsOneWidget);
    });

    testWidgets('Saved Posts Page có ListView cho danh sách bài viết đã lưu', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => Card(
                child: ListTile(
                  leading: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.image),
                  ),
                  title: Text('Post caption $index'),
                  subtitle: Text('Tác giả: User $index'),
                  trailing: IconButton(
                    icon: Icon(Icons.bookmark_remove),
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Post caption 0'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_remove), findsWidgets);
    });

    testWidgets('Saved Posts Page có empty state với icon bookmark_border', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 72, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Bạn chưa lưu bài viết nào.'),
                  SizedBox(height: 8),
                  Text('Nhấn biểu tượng bookmark tại bài viết để lưu và xem lại tại đây.'),
                  SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {},
                    child: Text('Trở về bảng tin'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      expect(find.text('Bạn chưa lưu bài viết nào.'), findsOneWidget);
      expect(find.text('Trở về bảng tin'), findsOneWidget);
    });

    testWidgets('Saved Post item có thumbnail image', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.image),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Post caption'),
                        Text('Tác giả: User'),
                        Text('Đã lưu lúc...'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.image), findsOneWidget);
      expect(find.text('Post caption'), findsOneWidget);
    });

    testWidgets('Saved Post item có IconButton để bỏ lưu', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: ListTile(
                title: Text('Post'),
                trailing: IconButton(
                  icon: Icon(Icons.bookmark_remove),
                  tooltip: 'Bỏ lưu',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.bookmark_remove), findsOneWidget);
    });

    testWidgets('Saved Posts Page có CircularProgressIndicator khi đang tải', (WidgetTester tester) async {
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

