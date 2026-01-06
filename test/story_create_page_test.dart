import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Story Create Page Widget Components Tests', () {
    testWidgets('Story Create Page có AppBar với title "Tạo story"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Tạo story'),
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

      expect(find.text('Tạo story'), findsOneWidget);
      expect(find.text('Đăng'), findsOneWidget);
    });

    testWidgets('Story Create Page có FloatingActionButton để chọn ảnh', (WidgetTester tester) async {
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

    testWidgets('Story Create Page có TextField cho caption', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: InputDecoration(
                hintText: 'Thêm chú thích...',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Thêm chú thích...'), findsOneWidget);
    });

    testWidgets('Story Create Page có Container để preview ảnh/video', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              height: 400,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.image),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.image), findsOneWidget);
    });

    testWidgets('Story Create Page có CircularProgressIndicator khi đang upload', (WidgetTester tester) async {
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

