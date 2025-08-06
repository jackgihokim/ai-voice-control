#!/bin/bash

# Quick fix for Xcode builds to enable permission dialogs
# Run this after building from Xcode

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
APP_PATH="$PROJECT_ROOT/DerivedData/AIVoiceControl/Build/Products/Debug/AIVoiceControl.app"

echo "🔧 Fixing Xcode build for permission dialogs..."

if [[ -d "$APP_PATH" ]]; then
    echo "📍 Found app at: $APP_PATH"
    
    # Remove quarantine attributes
    echo "🧹 Removing quarantine attributes..."
    xattr -cr "$APP_PATH"
    
    # Apply ad-hoc code signing
    echo "✍️ Applying ad-hoc code signing..."
    codesign --force --deep --sign - "$APP_PATH"
    
    echo "✅ Permission fixes applied!"
    echo ""
    echo "🚀 You can now run the app and permission dialogs should work."
    echo "   The app is located at: $APP_PATH"
    echo ""
    echo "💡 To launch the app: open \"$APP_PATH\""
    
else
    echo "❌ App not found at: $APP_PATH"
    echo "   Make sure you've built the project in Xcode first."
    exit 1
fi