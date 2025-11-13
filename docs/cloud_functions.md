# Cloud Functions đề xuất cho KMESS

Tài liệu này cung cấp skeleton cho các Cloud Functions phục vụ bảng tin:

1. **Thông báo khi có bình luận mới**  
   Trigger `functions.firestore.document('posts/{postId}/comments/{commentId}').onCreate(...)`  
   - Lấy `postId` → hydrate thông tin bài đăng (tác giả, token FCM).  
   - Gửi thông báo qua Firebase Cloud Messaging.  
   - Có thể ghi thêm bản ghi `notifications` trong Firestore để hiển thị lịch sử trong app.

2. **Thông báo khi có lượt thích mới**  
   Trigger tương tự trên `posts/{postId}/likes/{uid}` để báo cho tác giả bài đăng.

3. **Xử lý thumbnail/video** (tuỳ chọn)  
   Với video tải lên từ web (không có thumbnail client-side), có thể dùng Cloud Functions + ffmpeg để tạo ảnh preview.

4. **Đồng bộ `postsCount`**  
   Trigger `onCreate/onDelete` trên `posts/{postId}` để tăng/giảm trường `postsCount` của tác giả nhằm đảm bảo dữ liệu luôn chính xác.

```ts
import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

admin.initializeApp();

export const onNewComment = functions.firestore
  .document('posts/{postId}/comments/{commentId}')
  .onCreate(async (snap, context) => {
    const { postId } = context.params;
    const comment = snap.data();
    const postSnap = await admin.firestore().doc(`posts/${postId}`).get();
    if (!postSnap.exists) {
      return;
    }
    const post = postSnap.data()!;

    // Ví dụ: gửi thông báo đẩy
    const payload = {
      notification: {
        title: 'Bình luận mới',
        body: `${comment.authorUid} đã bình luận: ${comment.text}`,
      },
      data: {
        postId,
      },
    };

    // Lấy token FCM từ user_profiles hoặc collection tokens
    const tokenSnap = await admin
      .firestore()
      .collection('user_profiles')
      .doc(post.authorUid)
      .collection('tokens')
      .get();

    const tokens = tokenSnap.docs.map((doc) => doc.id);
    if (tokens.length) {
      await admin.messaging().sendToDevice(tokens, payload);
    }
  });
```

> Triển khai thực tế cần cài đặt `firebase-functions`, `firebase-admin` và nếu cần xử lý video/ảnh thì kèm thêm ffmpeg (có thể dùng `@ffmpeg-installer/ffmpeg`).  
> Lưu tệp dưới `functions/src/index.ts` (hoặc `index.js`) và triển khai bằng `firebase deploy --only functions`.

