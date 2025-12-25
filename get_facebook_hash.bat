@echo off
echo Getting Facebook Key Hash (Base64 format)...
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

REM Tìm openssl
set OPENSSL_PATH=
if exist "C:\Program Files\OpenSSL-Win64\bin\openssl.exe" (
    set OPENSSL_PATH=C:\Program Files\OpenSSL-Win64\bin\openssl.exe
) else if exist "C:\OpenSSL-Win64\bin\openssl.exe" (
    set OPENSSL_PATH=C:\OpenSSL-Win64\bin\openssl.exe
) else if exist "C:\Program Files (x86)\OpenSSL-Win32\bin\openssl.exe" (
    set OPENSSL_PATH=C:\Program Files (x86)\OpenSSL-Win32\bin\openssl.exe
)

if "%OPENSSL_PATH%"=="" (
    echo ========================================
    echo WARNING: OpenSSL not found!
    echo ========================================
    echo.
    echo Facebook requires Base64 format hash.
    echo You have two options:
    echo.
    echo Option 1: Install OpenSSL
    echo   Download from: https://slproweb.com/products/Win32OpenSSL.html
    echo   Or use: choco install openssl
    echo.
    echo Option 2: Use online converter
    echo   Your SHA-1 hash: 2B:A0:44:DF:6C:0B:8D:18:A0:72:0C:52:36:98:E0:05:B5:DB:D3:63
    echo   Remove colons: 2BA044DF6C0B8D18A0720C523698E005B5DBD363
    echo   Convert to Base64 using: https://base64.guru/converter/encode/hex
    echo.
    pause
    exit /b 1
)

echo Using OpenSSL at: %OPENSSL_PATH%
echo.

echo ========================================
echo DEBUG KEYSTORE HASH (Base64):
echo ========================================
"%KEYTOOL_PATH%" -exportcert -alias androiddebugkey -keystore "%USERPROFILE%\.android\debug.keystore" -storepass android -keypass android | "%OPENSSL_PATH%" sha1 -binary | "%OPENSSL_PATH%" base64

echo.
echo ========================================
echo Copy the hash above (28 characters) and paste into Facebook Developer Console
echo ========================================
echo.

REM Hỏi xem có release keystore không
set /p HAS_RELEASE="Do you have a release keystore? (y/n): "
if /i "%HAS_RELEASE%"=="y" (
    echo.
    set /p RELEASE_KEYSTORE="Enter path to release keystore: "
    set /p RELEASE_ALIAS="Enter key alias: "
    set /p RELEASE_PASSWORD="Enter keystore password: "
    
    echo.
    echo ========================================
    echo RELEASE KEYSTORE HASH (Base64):
    echo ========================================
    "%KEYTOOL_PATH%" -exportcert -alias "%RELEASE_ALIAS%" -keystore "%RELEASE_KEYSTORE%" -storepass "%RELEASE_PASSWORD%" | "%OPENSSL_PATH%" sha1 -binary | "%OPENSSL_PATH%" base64
    
    echo.
    echo ========================================
    echo Copy the hash above and paste into Facebook Developer Console
    echo ========================================
)

echo.
pause

