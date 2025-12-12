#!/bin/bash

echo "Deploying Firestore indexes..."
firebase deploy --only firestore:indexes

if [ $? -eq 0 ]; then
    echo ""
    echo "Indexes deployed successfully!"
    echo "Please wait 2-5 minutes for indexes to be built."
    echo "Check status at: https://console.firebase.google.com/project/duankmessapp/firestore/indexes"
else
    echo ""
    echo "Failed to deploy indexes."
    echo "Make sure you have:"
    echo "1. Installed Firebase CLI: npm install -g firebase-tools"
    echo "2. Logged in: firebase login"
    echo "3. Selected correct project: firebase use duankmessapp"
fi

