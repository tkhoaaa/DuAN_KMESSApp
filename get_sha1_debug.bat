@echo off
echo Getting SHA-1 and SHA-256 for DEBUG keystore...
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
    echo.
    echo You can also manually run:
    echo keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
    pause
    exit /b 1
)

echo Using keytool at: %KEYTOOL_PATH%
echo.

REM Tạo hash SHA-1 và SHA-256 cho debug keystore
echo ========================================
echo DEBUG KEYSTORE HASHES:
echo ========================================
"%KEYTOOL_PATH%" -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | findstr /C:"SHA1:" /C:"SHA256:"

echo.
echo ========================================
echo Copy the SHA-1 and SHA-256 values above
echo ========================================
pause

