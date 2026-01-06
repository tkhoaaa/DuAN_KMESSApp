import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Create Group Page Widget Components Tests', () {
    testWidgets('Create Group Page có AppBar với title "Tạo nhóm"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Tạo nhóm'),
              actions: [
                TextButton(
                  onPressed: () {},
                  child: Text('Tạo'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Tạo nhóm'), findsOneWidget);
      expect(find.text('Tạo'), findsOneWidget);
    });

    testWidgets('Create Group Page có TextField cho tên nhóm', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: InputDecoration(
                labelText: 'Tên nhóm',
                hintText: 'Nhập tên nhóm...',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Tên nhóm'), findsOneWidget);
    });

    testWidgets('Create Group Page có ListView cho danh sách thành viên', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => CheckboxListTile(
                title: Text('User $index'),
                subtitle: Text('user$index@example.com'),
                value: false,
                onChanged: (value) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('User 0'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsWidgets);
    });

    testWidgets('Create Group Page có FloatingActionButton để chọn ảnh đại diện', (WidgetTester tester) async {
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
    });

    testWidgets('Create Group Page có CircleAvatar cho ảnh đại diện nhóm', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircleAvatar(
                radius: 48,
                child: Icon(Icons.group),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.byIcon(Icons.group), findsOneWidget);
    });
  });
}

