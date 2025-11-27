# Script khắc phục lỗi emulator không kết nối
Write-Host "=== Khắc phục lỗi Emulator ===" -ForegroundColor Cyan

$ANDROID_SDK = "C:\Users\Admin\AppData\Local\Android\sdk"
$ADB = "$ANDROID_SDK\platform-tools\adb.exe"
$EMULATOR = "$ANDROID_SDK\emulator\emulator.exe"

# Bước 1: Kill tất cả process emulator và adb cũ
Write-Host "`n[1/5] Đang dừng các process emulator và ADB cũ..." -ForegroundColor Yellow
Get-Process | Where-Object {$_.ProcessName -like "*emulator*" -or $_.ProcessName -like "*qemu*"} | Stop-Process -Force -ErrorAction SilentlyContinue
& $ADB kill-server 2>$null
Start-Sleep -Seconds 2

# Bước 2: Khởi động lại ADB server
Write-Host "[2/5] Khởi động lại ADB server..." -ForegroundColor Yellow
& $ADB start-server
Start-Sleep -Seconds 2

# Bước 3: Liệt kê AVD có sẵn
Write-Host "[3/5] Đang liệt kê các AVD có sẵn..." -ForegroundColor Yellow
$avds = & $EMULATOR -list-avds
if ($avds.Count -eq 0) {
    Write-Host "Không tìm thấy AVD nào!" -ForegroundColor Red
    Write-Host "Vui lòng tạo AVD từ Android Studio > Device Manager" -ForegroundColor Yellow
    exit 1
}

Write-Host "Các AVD có sẵn:" -ForegroundColor Green
for ($i = 0; $i -lt $avds.Count; $i++) {
    Write-Host "  [$($i+1)] $($avds[$i])" -ForegroundColor Cyan
}

# Bước 4: Chọn AVD để khởi động
Write-Host "`n[4/5] Chọn AVD để khởi động (nhấn Enter để chọn AVD đầu tiên):" -ForegroundColor Yellow
$choice = Read-Host
if ([string]::IsNullOrWhiteSpace($choice)) {
    $selectedAvd = $avds[0]
} else {
    $index = [int]$choice - 1
    if ($index -ge 0 -and $index -lt $avds.Count) {
        $selectedAvd = $avds[$index]
    } else {
        $selectedAvd = $avds[0]
    }
}

Write-Host "Đã chọn: $selectedAvd" -ForegroundColor Green

# Bước 5: Khởi động emulator với cold boot và các tùy chọn tối ưu
Write-Host "`n[5/5] Đang khởi động emulator với cold boot..." -ForegroundColor Yellow
Write-Host "Lưu ý: Emulator sẽ mất 1-2 phút để khởi động hoàn toàn" -ForegroundColor Cyan

# Khởi động emulator với cold boot (xóa cache) và các tùy chọn tối ưu
$emulatorProcess = Start-Process -FilePath $EMULATOR `
    -ArgumentList "-avd", $selectedAvd, "-no-snapshot-load", "-wipe-data" `
    -PassThru -NoNewWindow

Write-Host "Emulator đang khởi động (PID: $($emulatorProcess.Id))..." -ForegroundColor Green
Write-Host "Đang chờ emulator sẵn sàng..." -ForegroundColor Yellow

# Chờ emulator boot xong (tối đa 120 giây)
$timeout = 120
$elapsed = 0
$bootComplete = $false

while ($elapsed -lt $timeout) {
    Start-Sleep -Seconds 5
    $elapsed += 5
    
    # Kiểm tra xem emulator đã boot chưa
    $devices = & $ADB devices 2>$null
    if ($devices -match "emulator.*device") {
        Write-Host "`n✓ Emulator đã sẵn sàng!" -ForegroundColor Green
        $bootComplete = $true
        break
    }
    
    Write-Host "." -NoNewline -ForegroundColor Gray
}

if (-not $bootComplete) {
    Write-Host "`n✗ Emulator không khởi động được trong $timeout giây" -ForegroundColor Red
    Write-Host "Vui lòng thử:" -ForegroundColor Yellow
    Write-Host "  1. Đóng tất cả emulator đang chạy" -ForegroundColor Cyan
    Write-Host "  2. Mở Android Studio > Device Manager" -ForegroundColor Cyan
    Write-Host "  3. Chọn emulator > Menu (3 chấm) > Cold Boot Now" -ForegroundColor Cyan
    exit 1
}

# Kiểm tra lại với Flutter
Write-Host "`nĐang kiểm tra với Flutter..." -ForegroundColor Yellow
flutter devices

Write-Host "`n✓ Hoàn tất! Bây giờ bạn có thể chạy: flutter run" -ForegroundColor Green

