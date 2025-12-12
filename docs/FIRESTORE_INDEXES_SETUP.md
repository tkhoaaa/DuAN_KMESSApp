# Hướng dẫn tạo Firestore Indexes cho Call History

## Vấn đề

Khi truy vấn lịch sử cuộc gọi, bạn có thể gặp lỗi:
```
[cloud_firestore/failed-precondition] The query requires an index
```

Lỗi này xảy ra vì Firestore cần **composite indexes** cho các query phức tạp (sử dụng `Filter.or` kết hợp với `orderBy`).

## Giải pháp

### Cách 1: Deploy indexes tự động (Khuyến nghị)

1. **Kiểm tra file indexes đã được cập nhật:**
   - File `firebase/firestore.indexes.json` đã chứa các indexes cần thiết cho collection `calls`

2. **Deploy indexes lên Firebase:**
   ```bash
   firebase deploy --only firestore:indexes
   ```

   Hoặc nếu chưa có Firebase CLI:
   ```bash
   npm install -g firebase-tools
   firebase login
   firebase deploy --only firestore:indexes
   ```

3. **Đợi indexes được tạo:**
   - Vào [Firebase Console](https://console.firebase.google.com/) > Firestore Database > Indexes
   - Kiểm tra trạng thái: **Building** → **Enabled** (thường mất 2-5 phút)

### Cách 2: Tạo indexes thủ công trên Firebase Console

1. Khi gặp lỗi `failed-precondition`, ứng dụng sẽ hiển thị dialog với link tạo index
2. Click **"Mở link"** hoặc copy link và mở trên trình duyệt
3. Firebase Console sẽ tự động điền thông tin index cần tạo
4. Click **"Create Index"**
5. Đợi index được tạo (2-5 phút)

### Cách 3: Tạo indexes từ error message

1. Khi gặp lỗi, copy URL từ error message
2. Mở URL trên trình duyệt
3. Firebase Console sẽ hiển thị form tạo index
4. Click **"Create Index"**

## Indexes đã được thêm vào file

File `firebase/firestore.indexes.json` đã bao gồm các indexes sau cho collection `calls`:

### 1. Index cho `callerUid + createdAt` (DESC)
- Dùng cho query lịch sử cuộc gọi khi user là người gọi
- Fields: `callerUid` (ASC), `createdAt` (DESC)

### 2. Index cho `calleeUid + createdAt` (DESC)
- Dùng cho query lịch sử cuộc gọi khi user là người nhận
- Fields: `calleeUid` (ASC), `createdAt` (DESC)

### 3. Index cho `callerUid + status`
- Dùng cho query active calls khi user là người gọi
- Fields: `callerUid` (ASC), `status` (ASC)

### 4. Index cho `calleeUid + status`
- Dùng cho query active calls khi user là người nhận
- Fields: `calleeUid` (ASC), `status` (ASC)

## Kiểm tra indexes đã được tạo

1. Vào [Firebase Console](https://console.firebase.google.com/)
2. Chọn project của bạn
3. Vào **Firestore Database** > **Indexes**
4. Tìm các indexes có collection = `calls`
5. Đảm bảo trạng thái là **Enabled** (màu xanh)

## Lưu ý

⚠️ **Indexes cần thời gian để build:**
- Indexes nhỏ: 1-2 phút
- Indexes lớn (nhiều documents): 5-10 phút
- Trong lúc build, query sẽ vẫn báo lỗi `failed-precondition`

✅ **Sau khi indexes được tạo:**
- Query sẽ hoạt động bình thường
- Không cần restart app
- Chỉ cần thử lại query

## Troubleshooting

### Index vẫn đang build nhưng đã quá lâu
- Kiểm tra số lượng documents trong collection `calls`
- Nếu có quá nhiều documents, có thể mất 10-15 phút
- Kiểm tra Firebase Console để xem tiến trình

### Vẫn gặp lỗi sau khi index đã Enabled
- Đảm bảo đã deploy đúng file `firebase/firestore.indexes.json`
- Kiểm tra lại query trong code có khớp với index không
- Thử restart app

### Không thể deploy indexes
- Kiểm tra đã login Firebase CLI: `firebase login`
- Kiểm tra đã chọn đúng project: `firebase use <project-id>`
- Kiểm tra file `firebase.json` có cấu hình đúng không

## Tài liệu tham khảo

- [Firestore Indexes Documentation](https://firebase.google.com/docs/firestore/query-data/indexing)
- [Firebase CLI Documentation](https://firebase.google.com/docs/cli)
- [Composite Indexes Guide](https://firebase.google.com/docs/firestore/query-data/index-overview#composite_indexes)

