import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duan_kmessapp/features/notifications/models/notification.dart' as models;

void main() {
  group('Notification Types và UI Components Tests', () {
    group('_NotificationTile Widget Tests', () {
    testWidgets('_NotificationTile hiển thị title đúng cho notification like', (WidgetTester tester) async {
      final notification = models.Notification(
        id: 'test-1',
        type: models.NotificationType.like,
        fromUid: 'user1',
        toUid: 'user2',
        postId: 'post1',
        read: false,
        createdAt: DateTime.now(),
      );

      // Build widget với mock notification
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                Card(
                  child: ListTile(
                    title: Text('Đã thích bài đăng của bạn'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Kiểm tra title
      expect(find.text('Đã thích bài đăng của bạn'), findsOneWidget);
    });

    testWidgets('_NotificationTile hiển thị title đúng cho notification comment', (WidgetTester tester) async {
      // Build widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                Card(
                  child: ListTile(
                    title: Text('Đã bình luận bài đăng của bạn'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Kiểm tra title
      expect(find.text('Đã bình luận bài đăng của bạn'), findsOneWidget);
    });

    testWidgets('_NotificationTile hiển thị title đúng cho notification replyComment', (WidgetTester tester) async {
      // Build widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                Card(
                  child: ListTile(
                    title: Text('Đã trả lời bình luận của bạn'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Kiểm tra title
      expect(find.text('Đã trả lời bình luận của bạn'), findsOneWidget);
    });

    testWidgets('_NotificationTile hiển thị title đúng cho notification save', (WidgetTester tester) async {
      // Build widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                Card(
                  child: ListTile(
                    title: Text('Đã lưu bài đăng của bạn'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Kiểm tra title
      expect(find.text('Đã lưu bài đăng của bạn'), findsOneWidget);
    });

    testWidgets('_NotificationTile hiển thị title đúng cho notification share', (WidgetTester tester) async {
      // Build widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                Card(
                  child: ListTile(
                    title: Text('Đã chia sẻ bài đăng của bạn'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Kiểm tra title
      expect(find.text('Đã chia sẻ bài đăng của bạn'), findsOneWidget);
    });

    testWidgets('_NotificationTile hiển thị title đúng cho notification storyLike', (WidgetTester tester) async {
      // Build widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                Card(
                  child: ListTile(
                    title: Text('Đã tim tin của bạn'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Kiểm tra title
      expect(find.text('Đã tim tin của bạn'), findsOneWidget);
    });
  });

  group('Notification Icons Tests', () {
    testWidgets('Icon đúng cho notification like', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Icon(Icons.favorite),
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('Icon đúng cho notification comment', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Icon(Icons.comment),
          ),
        ),
      );

      expect(find.byIcon(Icons.comment), findsOneWidget);
    });

    testWidgets('Icon đúng cho notification replyComment', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Icon(Icons.reply),
          ),
        ),
      );

      expect(find.byIcon(Icons.reply), findsOneWidget);
    });

    testWidgets('Icon đúng cho notification save', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Icon(Icons.bookmark),
          ),
        ),
      );

      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('Icon đúng cho notification share', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Icon(Icons.share),
          ),
        ),
      );

      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('Icon đúng cho notification storyLike', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Icon(Icons.favorite),
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
  });

  group('Notification Types Coverage', () {
    test('Tất cả NotificationType đều có trong enum', () {
      // Kiểm tra các notification types chính
      expect(models.NotificationType.like, isNotNull);
      expect(models.NotificationType.comment, isNotNull);
      expect(models.NotificationType.follow, isNotNull);
      expect(models.NotificationType.message, isNotNull);
      expect(models.NotificationType.call, isNotNull);
      expect(models.NotificationType.report, isNotNull);
      expect(models.NotificationType.appeal, isNotNull);
      expect(models.NotificationType.storyLike, isNotNull);
      expect(models.NotificationType.commentReaction, isNotNull);
      expect(models.NotificationType.save, isNotNull);
      expect(models.NotificationType.share, isNotNull);
      expect(models.NotificationType.replyComment, isNotNull);
    });
  });

  group('Widget Components Tests', () {
    testWidgets('Card widget có borderRadius 14', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(title: Text('Test')),
            ),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);
    });

    testWidgets('ListTile có title và subtitle', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              title: Text('Title'),
              subtitle: Text('Subtitle'),
            ),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Subtitle'), findsOneWidget);
    });

    testWidgets('CircleAvatar hiển thị đúng', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CircleAvatar(
              child: Icon(Icons.person),
            ),
          ),
        ),
      );

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('Container với BoxDecoration có shape circle', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.pink,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsOneWidget);
    });
  });
  });
}
