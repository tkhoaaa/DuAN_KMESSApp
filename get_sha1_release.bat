@echo off
echo Getting SHA-1 and SHA-256 for RELEASE keystore...
echo.

REM Tìm keytool trong Java SDK hoặc Android Studio
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

REM Yêu cầu người dùng nhập thông tin release keystore
set /p KEYSTORE_PATH="Enter path to your release keystore (e.g., C:\path\to\your\release.keystore): "
set /p KEY_ALIAS="Enter key alias (e.g., upload): "
set /p KEYSTORE_PASSWORD="Enter keystore password: "

if "%KEYSTORE_PATH%"=="" (
    echo ERROR: Keystore path is required
    pause
    exit /b 1
)

if not exist "%KEYSTORE_PATH%" (
    echo ERROR: Keystore file not found: %KEYSTORE_PATH%
    pause
    exit /b 1
)

echo.
echo ========================================
echo RELEASE KEYSTORE HASHES:
echo ========================================
"%KEYTOOL_PATH%" -list -v -keystore "%KEYSTORE_PATH%" -alias "%KEY_ALIAS%" -storepass "%KEYSTORE_PASSWORD%" | findstr /C:"SHA1:" /C:"SHA256:"

echo.
echo ========================================
echo Copy the SHA-1 and SHA-256 values above
echo ========================================
pause

