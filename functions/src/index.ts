import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Gửi thông báo khi có bình luận mới trên bài đăng
 */
export const onNewComment = functions.firestore
  .document('posts/{postId}/comments/{commentId}')
  .onCreate(async (snap: functions.firestore.QueryDocumentSnapshot, context: functions.EventContext) => {
    const { postId, commentId } = context.params;
    const comment = snap.data();
    const commenterUid = comment.authorUid as string;

    // Lấy thông tin bài đăng
    const postSnap = await db.doc(`posts/${postId}`).get();
    if (!postSnap.exists) {
      console.warn(`Post ${postId} not found for comment ${commentId}`);
      return;
    }

    const post = postSnap.data()!;
    const authorUid = post.authorUid as string;

    // Không gửi thông báo nếu người bình luận là chính tác giả
    if (commenterUid === authorUid) {
      return;
    }

    // Lấy thông tin người bình luận
    const commenterProfile = await db.doc(`user_profiles/${commenterUid}`).get();
    const commenterName = commenterProfile.data()?.displayName || 'Ai đó';

    // Lấy FCM tokens của tác giả bài đăng
    const tokensSnap = await db
      .collection('user_profiles')
      .doc(authorUid)
      .collection('fcm_tokens')
      .get();

    if (tokensSnap.empty) {
      console.log(`No FCM tokens found for user ${authorUid}`);
      return;
    }

    const tokens = tokensSnap.docs.map((doc: admin.firestore.QueryDocumentSnapshot) => doc.id);

    // Tạo thông báo
    const payload: admin.messaging.MulticastMessage = {
      notification: {
        title: 'Bình luận mới',
        body: `${commenterName} đã bình luận: ${(comment.text as string).substring(0, 50)}${(comment.text as string).length > 50 ? '...' : ''}`,
      },
      data: {
        type: 'comment',
        postId,
        commentId,
        commenterUid,
      },
      tokens,
    };

    try {
      const response = await messaging.sendEachForMulticast(payload);
      console.log(`Sent ${response.successCount} notifications for comment ${commentId}`);
    } catch (error) {
      console.error('Error sending comment notification:', error);
    }

    // Tạo bản ghi notification trong Firestore (tùy chọn)
    await db.collection('user_profiles').doc(authorUid).collection('notifications').add({
      type: 'comment',
      postId,
      commentId,
      commenterUid,
      text: comment.text,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

/**
 * Gửi thông báo khi có lượt thích mới
 */
export const onNewLike = functions.firestore
  .document('posts/{postId}/likes/{uid}')
  .onCreate(async (snap: functions.firestore.QueryDocumentSnapshot, context: functions.EventContext) => {
    const { postId, uid: likerUid } = context.params;

    // Lấy thông tin bài đăng
    const postSnap = await db.doc(`posts/${postId}`).get();
    if (!postSnap.exists) {
      console.warn(`Post ${postId} not found for like from ${likerUid}`);
      return;
    }

    const post = postSnap.data()!;
    const authorUid = post.authorUid as string;

    // Không gửi thông báo nếu người like là chính tác giả
    if (likerUid === authorUid) {
      return;
    }

    // Lấy thông tin người like
    const likerProfile = await db.doc(`user_profiles/${likerUid}`).get();
    const likerName = likerProfile.data()?.displayName || 'Ai đó';

    // Lấy FCM tokens của tác giả
    const tokensSnap = await db
      .collection('user_profiles')
      .doc(authorUid)
      .collection('fcm_tokens')
      .get();

    if (tokensSnap.empty) {
      console.log(`No FCM tokens found for user ${authorUid}`);
      return;
    }

    const tokens = tokensSnap.docs.map((doc: admin.firestore.QueryDocumentSnapshot) => doc.id);

    // Tạo thông báo
    const payload: admin.messaging.MulticastMessage = {
      notification: {
        title: 'Lượt thích mới',
        body: `${likerName} đã thích bài đăng của bạn`,
      },
      data: {
        type: 'like',
        postId,
        likerUid,
      },
      tokens,
    };

    try {
      const response = await messaging.sendEachForMulticast(payload);
      console.log(`Sent ${response.successCount} notifications for like on post ${postId}`);
    } catch (error) {
      console.error('Error sending like notification:', error);
    }

    // Tạo bản ghi notification (tùy chọn)
    await db.collection('user_profiles').doc(authorUid).collection('notifications').add({
      type: 'like',
      postId,
      likerUid,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

/**
 * Đồng bộ postsCount khi tạo/xóa bài đăng
 */
export const syncPostsCount = functions.firestore
  .document('posts/{postId}')
  .onCreate(async (snap: functions.firestore.QueryDocumentSnapshot, context: functions.EventContext) => {
    const post = snap.data();
    const authorUid = post.authorUid as string;

    await db.doc(`user_profiles/${authorUid}`).update({
      postsCount: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Incremented postsCount for user ${authorUid}`);
  });

export const syncPostsCountOnDelete = functions.firestore
  .document('posts/{postId}')
  .onDelete(async (snap: functions.firestore.QueryDocumentSnapshot, context: functions.EventContext) => {
    const post = snap.data();
    const authorUid = post.authorUid as string;

    await db.doc(`user_profiles/${authorUid}`).update({
      postsCount: admin.firestore.FieldValue.increment(-1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Decremented postsCount for user ${authorUid}`);
  });

