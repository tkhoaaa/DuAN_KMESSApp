# PowerShell script to get SHA-1 fingerprint for Google Sign-In

Write-Host "Getting SHA-1 fingerprint for Google Sign-In..." -ForegroundColor Cyan
Write-Host ""

# Try to get SHA-1 using gradlew
if (Test-Path "android\gradlew.bat") {
    Write-Host "Using gradlew..." -ForegroundColor Yellow
    Push-Location android
    & .\gradlew.bat signingReport
    Pop-Location
    Write-Host ""
    Write-Host "Look for 'SHA1:' in the output above" -ForegroundColor Green
    Write-Host "Copy the SHA-1 value and add it to Firebase Console" -ForegroundColor Green
    Read-Host "Press Enter to exit"
    exit 0
}

# Try to find keystore in common locations
$keystorePath = $null

$possiblePaths = @(
    "$env:USERPROFILE\.android\debug.keystore",
    "$env:LOCALAPPDATA\Android\Sdk\.android\debug.keystore"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $keystorePath = $path
        break
    }
}

if ($null -eq $keystorePath) {
    Write-Host "Keystore not found in default locations." -ForegroundColor Red
    Write-Host ""
    Write-Host "The debug keystore will be created automatically when you first build the app." -ForegroundColor Yellow
    Write-Host "Please build the app first, then run this script again." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or create it manually with:" -ForegroundColor Yellow
    Write-Host "keytool -genkey -v -keystore `"$env:USERPROFILE\.android\debug.keystore`" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000" -ForegroundColor Cyan
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Using keytool with keystore: $keystorePath" -ForegroundColor Yellow
keytool -list -v -keystore "$keystorePath" -alias androiddebugkey -storepass android -keypass android

Write-Host ""
Write-Host "Look for 'SHA1:' in the output above" -ForegroundColor Green
Write-Host "Copy the SHA-1 value and add it to Firebase Console" -ForegroundColor Green
Read-Host "Press Enter to exit"

