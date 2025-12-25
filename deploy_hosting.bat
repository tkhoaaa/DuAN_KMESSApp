@echo off
echo ========================================
echo Deploy Firebase Hosting
echo ========================================
echo.

echo Checking Firebase CLI...
firebase --version >nul 2>&1
if errorlevel 1 (
    echo Firebase CLI not found. Installing...
    npm install -g firebase-tools
    if errorlevel 1 (
        echo Failed to install Firebase CLI
        pause
        exit /b 1
    )
)

echo.
echo Logging in to Firebase...
firebase login
if errorlevel 1 (
    echo Failed to login to Firebase
    pause
    exit /b 1
)

echo.
echo Deploying hosting...
firebase deploy --only hosting
if errorlevel 1 (
    echo Deployment failed
    pause
    exit /b 1
)

echo.
echo ========================================
echo Deployment completed successfully!
echo ========================================
echo.
echo URLs:
echo - Privacy Policy: https://duankmessapp.firebaseapp.com/privacy-policy.html
echo - Terms of Service: https://duankmessapp.firebaseapp.com/terms-of-service.html
echo - User Data Deletion: https://duankmessapp.firebaseapp.com/user-data-deletion.html
echo.
pause

