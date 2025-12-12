#!/bin/bash

echo "========================================"
echo "Facebook Hash Key Generator"
echo "========================================"
echo ""

# Check if debug.keystore exists
if [ ! -f ~/.android/debug.keystore ]; then
    echo "ERROR: debug.keystore not found at: ~/.android/debug.keystore"
    echo ""
    echo "Please run your Flutter app once to generate the debug.keystore"
    echo "Or create it manually using Android Studio."
    echo ""
    exit 1
fi

echo "Generating development hash key..."
echo ""

# Generate hash key
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64

echo ""
echo "========================================"
echo "Copy the hash key above and paste it into Facebook Developer Console"
echo "========================================"
echo ""

