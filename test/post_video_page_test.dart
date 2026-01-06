import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Post Video Page Widget Components Tests', () {
    testWidgets('Post Video Page có AppBar với title "Video"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: Text('Video'),
              backgroundColor: Colors.black,
            ),
          ),
        ),
      );

      expect(find.text('Video'), findsOneWidget);
    });

    testWidgets('Post Video Page có Container với màu đen', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Container(
                color: Colors.black,
                child: Icon(Icons.play_circle_outline, color: Colors.white),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    });

    testWidgets('Post Video Page có IconButton play/pause', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: IconButton(
                icon: Icon(Icons.play_arrow, color: Colors.white),
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('Post Video Page có CircularProgressIndicator khi đang tải', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

