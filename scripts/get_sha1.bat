@echo off
echo Getting SHA-1 fingerprint for Google Sign-In...
echo.

REM Try to get SHA-1 using gradlew
if exist "android\gradlew.bat" (
    echo Using gradlew...
    cd android
    call .\gradlew.bat signingReport
    cd ..
    echo.
    echo Look for "SHA1:" in the output above
    echo Copy the SHA-1 value and add it to Firebase Console
    pause
    exit /b
)

REM Try to find keystore in common locations
set KEYSTORE_PATH=
if exist "%USERPROFILE%\.android\debug.keystore" (
    set KEYSTORE_PATH=%USERPROFILE%\.android\debug.keystore
) else if exist "%LOCALAPPDATA%\Android\Sdk\.android\debug.keystore" (
    set KEYSTORE_PATH=%LOCALAPPDATA%\Android\Sdk\.android\debug.keystore
) else (
    echo Keystore not found in default locations.
    echo.
    echo Please provide the path to your debug.keystore file:
    set /p KEYSTORE_PATH="Keystore path: "
)

if "%KEYSTORE_PATH%"=="" (
    echo.
    echo ERROR: Keystore file not found!
    echo.
    echo The debug keystore will be created automatically when you first build the app.
    echo Please build the app first, then run this script again.
    echo.
    echo Or create it manually with:
    echo keytool -genkey -v -keystore "%USERPROFILE%\.android\debug.keystore" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000
    pause
    exit /b 1
)

echo Using keytool with keystore: %KEYSTORE_PATH%
keytool -list -v -keystore "%KEYSTORE_PATH%" -alias androiddebugkey -storepass android -keypass android

echo.
echo Look for "SHA1:" in the output above
echo Copy the SHA-1 value and add it to Firebase Console
pause

