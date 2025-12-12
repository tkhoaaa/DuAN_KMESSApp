#!/bin/bash

echo "Getting SHA-1 fingerprint for Google Sign-In..."
echo ""

# Try to get SHA-1 using gradlew
if [ -f "android/gradlew" ]; then
    echo "Using gradlew..."
    cd android
    ./gradlew signingReport
    cd ..
    echo ""
    echo "Look for 'SHA1:' in the output above"
    echo "Copy the SHA-1 value and add it to Firebase Console"
    exit 0
fi

# Fallback: use keytool directly
echo "Using keytool directly..."
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

echo ""
echo "Look for 'SHA1:' in the output above"
echo "Copy the SHA-1 value and add it to Firebase Console"

