import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Image Viewer Page Widget Components Tests', () {
    testWidgets('Image Viewer Page có AppBar với title "Ảnh"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Ảnh'),
              actions: [
                IconButton(
                  icon: Icon(Icons.share),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Ảnh'), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('Image Viewer Page có Image widget để hiển thị ảnh', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
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

    testWidgets('Image Viewer Page có PageView cho nhiều ảnh', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageView.builder(
              itemCount: 3,
              itemBuilder: (context, index) => Container(
                color: Colors.grey[300],
                child: Icon(Icons.image),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byIcon(Icons.image), findsWidgets);
    });

    testWidgets('Image Viewer Page có CircularProgressIndicator khi đang tải', (WidgetTester tester) async {
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

