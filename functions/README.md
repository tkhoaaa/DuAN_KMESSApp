# Cloud Functions Setup

## Cài đặt Dependencies

Trước khi build hoặc deploy, cần cài đặt dependencies:

```bash
cd functions
npm install
```

## Build

```bash
npm run build
```

## Deploy

```bash
# Deploy tất cả functions
npm run deploy

# Hoặc
firebase deploy --only functions
```

## Lưu ý

- Đảm bảo đã chạy `firebase login` và `firebase use --add` trước khi deploy
- Xem [../docs/deploy_guide.md](../docs/deploy_guide.md) để biết chi tiết

