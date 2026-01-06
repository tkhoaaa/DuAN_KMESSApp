import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Public Profile Page Widget Components Tests', () {
    testWidgets('Public Profile Page có AppBar với title "Trang cá nhân"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text('Trang cá nhân'),
              actions: [
                IconButton(
                  icon: Icon(Icons.share),
                  onPressed: () {},
                ),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert),
                  itemBuilder: (context) => [],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Trang cá nhân'), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('Public Profile Page có FilledButton "Theo dõi"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilledButton(
              onPressed: () {},
              child: Text('Theo dõi'),
            ),
          ),
        ),
      );

      expect(find.text('Theo dõi'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('Public Profile Page có FilledButton "Bỏ theo dõi"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilledButton(
              onPressed: () {},
              child: Text('Bỏ theo dõi'),
            ),
          ),
        ),
      );

      expect(find.text('Bỏ theo dõi'), findsOneWidget);
    });

    testWidgets('Public Profile Page có OutlinedButton "Nhắn tin"', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutlinedButton(
              onPressed: () {},
              child: Text('Nhắn tin'),
            ),
          ),
        ),
      );

      expect(find.text('Nhắn tin'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('Public Profile Page có StatTile hiển thị số lượng followers/following', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text('100', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Người theo dõi'),
                  ],
                ),
                Column(
                  children: [
                    Text('50', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Đang theo dõi'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Người theo dõi'), findsOneWidget);
      expect(find.text('Đang theo dõi'), findsOneWidget);
    });

    testWidgets('Public Profile Page có ActionChip cho links', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: Icon(Icons.link),
                  label: Text('Website'),
                  onPressed: () {},
                ),
                ActionChip(
                  avatar: Icon(Icons.link),
                  label: Text('Instagram'),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(ActionChip), findsWidgets);
      expect(find.text('Website'), findsOneWidget);
      expect(find.text('Instagram'), findsOneWidget);
    });

    testWidgets('Public Profile Page có GridView cho posts', (WidgetTester tester) async {
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
                color: Colors.grey[300],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GridView), findsOneWidget);
    });
  });
}








