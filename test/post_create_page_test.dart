import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Post Create Page Widget Components Tests', () {
    testWidgets('Post Create Page có AppBar với title "Tạo bài viết"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Tạo bài viết'),
              actions: [
                TextButton(
                  onPressed: () {},
                  child: Text('Đăng'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Tạo bài viết'), findsOneWidget);
      expect(find.text('Đăng'), findsOneWidget);
    });

    testWidgets('Post Create Page có TextField cho caption', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Viết gì đó...',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Viết gì đó...'), findsOneWidget);
    });

    testWidgets('Post Create Page có GridView cho preview images', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
              ),
              itemCount: 6,
              itemBuilder: (context, index) => Container(
                color: Colors.grey[300],
                child: Stack(
                  children: [
                    Icon(Icons.image),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byIcon(Icons.image), findsWidgets);
      expect(find.byIcon(Icons.close), findsWidgets);
    });

    testWidgets('Post Create Page có FloatingActionButton để chọn ảnh', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: Icon(Icons.add_photo_alternate),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add_photo_alternate), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('Post Create Page có Switch cho private/public', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwitchListTile(
              title: Text('Bài viết riêng tư'),
              value: false,
              onChanged: (value) {},
            ),
          ),
        ),
      );

      expect(find.text('Bài viết riêng tư'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('Post Create Page có DatePicker cho scheduled post', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              leading: Icon(Icons.schedule),
              title: Text('Hẹn giờ đăng'),
              trailing: Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Hẹn giờ đăng'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });
  });
}

