@echo off
echo ========================================
echo Facebook Hash Key Generator
echo ========================================
echo.

REM Check if OpenSSL is available
where openssl >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: OpenSSL not found!
    echo.
    echo Please install OpenSSL or use Git Bash instead.
    echo Download from: https://slproweb.com/products/Win32OpenSSL.html
    echo.
    echo Alternative: Use Git Bash and run:
    echo   keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android ^| openssl sha1 -binary ^| openssl base64
    echo.
    pause
    exit /b 1
)

REM Check if debug.keystore exists
if not exist "%USERPROFILE%\.android\debug.keystore" (
    echo ERROR: debug.keystore not found at: %USERPROFILE%\.android\debug.keystore
    echo.
    echo Please run your Flutter app once to generate the debug.keystore
    echo Or create it manually using Android Studio.
    echo.
    pause
    exit /b 1
)

echo Generating development hash key...
echo.

REM Generate hash key
keytool -exportcert -alias androiddebugkey -keystore "%USERPROFILE%\.android\debug.keystore" -storepass android -keypass android | openssl sha1 -binary | openssl base64

echo.
echo ========================================
echo Copy the hash key above and paste it into Facebook Developer Console
echo ========================================
echo.
pause

