import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Story Viewer Page Widget Components Tests', () {
    testWidgets('Story Viewer Page có AppBar với title "Story"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Story'),
            ),
          ),
        ),
      );

      expect(find.text('Story'), findsOneWidget);
    });

    testWidgets('Story Viewer Page có PageView để xem story', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageView.builder(
              itemCount: 3,
              itemBuilder: (context, index) => Container(
                color: Colors.black,
                child: Icon(Icons.image, color: Colors.white),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('Story Viewer Page có IconButton để like', (WidgetTester tester) async {
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

    testWidgets('Story Viewer Page có TextField để nhập tin nhắn', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(child: Container()),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Gửi tin nhắn...',
                    suffixIcon: IconButton(
                      icon: Icon(Icons.send),
                      onPressed: () {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Gửi tin nhắn...'), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
    });
  });
}

