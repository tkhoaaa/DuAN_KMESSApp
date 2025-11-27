@echo off
echo ========================================
echo   Khởi động Android Emulator
echo ========================================
echo.

set ANDROID_SDK=C:\Users\Admin\AppData\Local\Android\sdk
set ADB=%ANDROID_SDK%\platform-tools\adb.exe
set EMULATOR=%ANDROID_SDK%\emulator\emulator.exe

echo [1/4] Dang dung cac emulator cu...
taskkill /F /IM emulator.exe /T >nul 2>&1
taskkill /F /IM qemu-system-x86_64.exe /T >nul 2>&1
%ADB% kill-server >nul 2>&1
timeout /t 2 /nobreak >nul

echo [2/4] Khoi dong lai ADB server...
%ADB% start-server
timeout /t 2 /nobreak >nul

echo [3/4] Danh sach AVD co san:
%EMULATOR% -list-avds
echo.

echo [4/4] Vui long chon AVD de khoi dong:
echo    - Neu ban co "Medium Phone API 36.0", nhap: Medium_Phone_API_36.0
echo    - Neu ban co "VoTienKhoa-Pixel 8", nhap: VoTienKhoa-Pixel_8
echo    - Hoac nhap ten AVD chinh xac tu danh sach tren
echo.
set /p AVD_NAME="Nhap ten AVD: "

if "%AVD_NAME%"=="" (
    echo Loi: Ban phai nhap ten AVD!
    pause
    exit /b 1
)

echo.
echo Dang khoi dong emulator: %AVD_NAME%
echo Luu y: Emulator se mat 1-2 phut de khoi dong hoan toan
echo.

REM Khoi dong emulator voi cold boot
start "" "%EMULATOR%" -avd %AVD_NAME% -no-snapshot-load

echo.
echo Emulator dang khoi dong...
echo Doi 60 giay roi kiem tra lai...
timeout /t 60 /nobreak

echo.
echo Kiem tra thiet bi...
%ADB% devices
echo.
flutter devices

echo.
echo ========================================
echo Neu emulator da online, chay: flutter run
echo ========================================
pause

