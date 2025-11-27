    # Script để khởi động emulator và chạy Flutter app
Write-Host "Đang kiểm tra emulator..." -ForegroundColor Yellow

# Kiểm tra xem có emulator nào đang chạy không
$devices = flutter devices 2>&1 | Out-String
if ($devices -match "emulator.*online") {
    Write-Host "Emulator đã sẵn sàng!" -ForegroundColor Green
    flutter run
} else {
    Write-Host "Emulator chưa sẵn sàng. Vui lòng:" -ForegroundColor Red
    Write-Host "1. Mở Android Studio" -ForegroundColor Cyan
    Write-Host "2. Vào Device Manager (biểu tượng điện thoại)" -ForegroundColor Cyan
    Write-Host "3. Chọn emulator và nhấn Play để khởi động" -ForegroundColor Cyan
    Write-Host "4. Đợi emulator khởi động xong, sau đó chạy lại script này" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Hoặc chạy lệnh: flutter devices" -ForegroundColor Yellow
}

