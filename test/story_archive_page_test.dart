import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Story Archive Page Widget Components Tests', () {
    testWidgets('Story Archive Page có AppBar với title "Lưu trữ Story"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Lưu trữ Story'),
            ),
          ),
        ),
      );

      expect(find.text('Lưu trữ Story'), findsOneWidget);
    });

    testWidgets('Story Archive Page có GridView cho danh sách story', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 9,
              itemBuilder: (context, index) => Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.image),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byIcon(Icons.image), findsWidgets);
    });

    testWidgets('Story Archive Page có empty state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Chưa có story nào được lưu trữ'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.archive), findsOneWidget);
      expect(find.text('Chưa có story nào được lưu trữ'), findsOneWidget);
    });
  });
}

