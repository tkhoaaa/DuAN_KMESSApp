# PowerShell script to get Facebook Key Hash in Base64 format

Write-Host "Getting Facebook Key Hash (Base64 format)..." -ForegroundColor Cyan
Write-Host ""

# Find keytool
$keytoolPath = $null
$possiblePaths = @(
    "$env:JAVA_HOME\bin\keytool.exe",
    "$env:ANDROID_HOME\jbr\bin\keytool.exe",
    "$env:LOCALAPPDATA\Android\Sdk\jbr\bin\keytool.exe",
    "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $keytoolPath = $path
        break
    }
}

if (-not $keytoolPath) {
    Write-Host "ERROR: Cannot find keytool.exe" -ForegroundColor Red
    Write-Host "Please install Java JDK or Android Studio" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Using keytool at: $keytoolPath" -ForegroundColor Green
Write-Host ""

# Function to convert hex string to base64
function Convert-HexToBase64 {
    param([string]$hexString)
    
    # Remove colons and spaces
    $hexString = $hexString -replace '[: ]', ''
    
    # Convert hex to bytes
    $bytes = for ($i = 0; $i -lt $hexString.Length; $i += 2) {
        [Convert]::ToByte($hexString.Substring($i, 2), 16)
    }
    
    # Convert bytes to base64
    [Convert]::ToBase64String($bytes)
}

# Get debug keystore hash
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "DEBUG KEYSTORE HASH (Base64):" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

$debugKeystore = "$env:USERPROFILE\.android\debug.keystore"

if (Test-Path $debugKeystore) {
    # Get certificate in PEM format
    $certOutput = & $keytoolPath -exportcert -alias androiddebugkey -keystore $debugKeystore -storepass android -keypass android 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        # Extract SHA-1 from certificate
        $sha1Output = & $keytoolPath -list -v -keystore $debugKeystore -alias androiddebugkey -storepass android -keypass android 2>&1 | Select-String "SHA1:"
        
        if ($sha1Output) {
            $sha1Hash = ($sha1Output -split "SHA1:")[1].Trim()
            $base64Hash = Convert-HexToBase64 -hexString $sha1Hash
            Write-Host $base64Hash -ForegroundColor Green
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host "Copy the hash above (28 characters) and paste into Facebook Developer Console" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Yellow
        } else {
            Write-Host "Could not extract SHA-1 hash" -ForegroundColor Red
        }
    } else {
        Write-Host "Error exporting certificate: $certOutput" -ForegroundColor Red
    }
} else {
    Write-Host "Debug keystore not found at: $debugKeystore" -ForegroundColor Red
}

Write-Host ""

# Ask for release keystore
$hasRelease = Read-Host "Do you have a release keystore? (y/n)"
if ($hasRelease -eq "y" -or $hasRelease -eq "Y") {
    Write-Host ""
    $releaseKeystore = Read-Host "Enter path to release keystore"
    $releaseAlias = Read-Host "Enter key alias"
    $releasePassword = Read-Host "Enter keystore password" -AsSecureString
    $releasePasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($releasePassword))
    
    if (Test-Path $releaseKeystore) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "RELEASE KEYSTORE HASH (Base64):" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        
        $sha1Output = & $keytoolPath -list -v -keystore $releaseKeystore -alias $releaseAlias -storepass $releasePasswordPlain 2>&1 | Select-String "SHA1:"
        
        if ($sha1Output) {
            $sha1Hash = ($sha1Output -split "SHA1:")[1].Trim()
            $base64Hash = Convert-HexToBase64 -hexString $sha1Hash
            Write-Host $base64Hash -ForegroundColor Green
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host "Copy the hash above and paste into Facebook Developer Console" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Yellow
        } else {
            Write-Host "Could not extract SHA-1 hash" -ForegroundColor Red
        }
    } else {
        Write-Host "Release keystore not found at: $releaseKeystore" -ForegroundColor Red
    }
}

Write-Host ""
Read-Host "Press Enter to exit"

