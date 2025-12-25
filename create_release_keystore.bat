@echo off
echo Creating Release Keystore for Android App...
echo.

REM Tìm keytool
set KEYTOOL_PATH=
if exist "%JAVA_HOME%\bin\keytool.exe" (
    set KEYTOOL_PATH=%JAVA_HOME%\bin\keytool.exe
) else if exist "%ANDROID_HOME%\jbr\bin\keytool.exe" (
    set KEYTOOL_PATH=%ANDROID_HOME%\jbr\bin\keytool.exe
) else if exist "%LOCALAPPDATA%\Android\Sdk\jbr\bin\keytool.exe" (
    set KEYTOOL_PATH=%LOCALAPPDATA%\Android\Sdk\jbr\bin\keytool.exe
) else if exist "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" (
    set KEYTOOL_PATH=C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe
)

if "%KEYTOOL_PATH%"=="" (
    echo ERROR: Cannot find keytool.exe
    echo Please install Java JDK or Android Studio
    pause
    exit /b 1
)

echo Using keytool at: %KEYTOOL_PATH%
echo.

REM Tạo thư mục android/app nếu chưa có
if not exist "android\app" mkdir android\app

set KEYSTORE_PATH=android\app\release.keystore
set KEY_ALIAS=upload
set VALIDITY=10000

echo This will create a release keystore at: %KEYSTORE_PATH%
echo.
echo IMPORTANT: Please remember the following information:
echo - Keystore password (you'll need to enter it twice)
echo - Key alias: %KEY_ALIAS%
echo - Key password (can be same as keystore password)
echo.
echo Press any key to continue...
pause >nul

"%KEYTOOL_PATH%" -genkey -v -keystore "%KEYSTORE_PATH%" -alias %KEY_ALIAS% -keyalg RSA -keysize 2048 -validity %VALIDITY%

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo Release keystore created successfully!
    echo ========================================
    echo Location: %KEYSTORE_PATH%
    echo Alias: %KEY_ALIAS%
    echo.
    echo IMPORTANT: Save this keystore file and passwords securely!
    echo You will need them to publish updates to your app.
    echo.
) else (
    echo.
    echo ERROR: Failed to create keystore
    echo.
)

pause

