# Script Cold Boot Emulator (đơn giản)
$ANDROID_SDK = "C:\Users\Admin\AppData\Local\Android\sdk"
$EMULATOR = "$ANDROID_SDK\emulator\emulator.exe"

Write-Host "Đang dừng tất cả emulator..." -ForegroundColor Yellow
Get-Process | Where-Object {$_.ProcessName -like "*emulator*" -or $_.ProcessName -like "*qemu*"} | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "`nDanh sách AVD:" -ForegroundColor Cyan
$avds = & $EMULATOR -list-avds
for ($i = 0; $i -lt $avds.Count; $i++) {
    Write-Host "  [$($i+1)] $($avds[$i])" -ForegroundColor White
}

if ($avds.Count -eq 0) {
    Write-Host "Không có AVD nào!" -ForegroundColor Red
    exit
}

Write-Host "`nNhập số thứ tự AVD (hoặc Enter để chọn đầu tiên): " -NoNewline -ForegroundColor Yellow
$choice = Read-Host
if ([string]::IsNullOrWhiteSpace($choice)) {
    $avdName = $avds[0]
} else {
    $index = [int]$choice - 1
    $avdName = if ($index -ge 0 -and $index -lt $avds.Count) { $avds[$index] } else { $avds[0] }
}

Write-Host "`nĐang khởi động: $avdName" -ForegroundColor Green
Write-Host "Lưu ý: Cold boot sẽ mất 1-2 phút..." -ForegroundColor Cyan

# Cold boot: -no-snapshot-load để không load snapshot, khởi động từ đầu
Start-Process -FilePath $EMULATOR -ArgumentList "-avd", $avdName, "-no-snapshot-load"

Write-Host "`nĐã khởi động emulator. Đợi 1-2 phút rồi chạy: flutter devices" -ForegroundColor Green



