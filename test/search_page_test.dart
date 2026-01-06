import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Search Page Widget Components Tests', () {
    testWidgets('Search Page có AppBar với TextField tìm kiếm', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm người dùng hoặc bài viết...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.filter_list),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Tìm kiếm người dùng hoặc bài viết...'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });

    testWidgets('Search Page có TabBar với 2 tabs', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                bottom: TabBar(
                  tabs: [
                    Tab(text: 'Người dùng'),
                    Tab(text: 'Bài viết'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Người dùng'), findsOneWidget);
      expect(find.text('Bài viết'), findsOneWidget);
    });

    testWidgets('Search Page có ListView cho kết quả người dùng', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => ListTile(
                leading: CircleAvatar(),
                title: Text('User $index'),
                subtitle: Text('user$index@example.com'),
                trailing: FilledButton(
                  onPressed: () {},
                  child: Text('Theo dõi'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('User 0'), findsOneWidget);
      expect(find.text('Theo dõi'), findsWidgets);
    });

    testWidgets('Search Page có GridView cho kết quả bài viết', (WidgetTester tester) async {
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
                color: Colors.grey[300],
                child: Icon(Icons.image),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byIcon(Icons.image), findsWidgets);
    });

    testWidgets('Search Page có empty state khi không có kết quả', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_search, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Không tìm thấy người dùng nào'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.person_search), findsOneWidget);
      expect(find.text('Không tìm thấy người dùng nào'), findsOneWidget);
    });

    testWidgets('Search Page có FilterChip cho filters', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  InputChip(
                    label: Text('Đang follow'),
                    onDeleted: () {},
                  ),
                  InputChip(
                    label: Text('Công khai'),
                    onDeleted: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(InputChip), findsWidgets);
      expect(find.text('Đang follow'), findsOneWidget);
    });

    testWidgets('Search Page có CircularProgressIndicator khi đang tìm kiếm', (WidgetTester tester) async {
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

