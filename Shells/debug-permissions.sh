#!/bin/bash

echo "🔍 Debugging permission issues..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="$PROJECT_ROOT/DerivedData/AIVoiceControl/Build/Products/Debug/AIVoiceControl.app"
BUNDLE_ID="com.jack-kim-dev.AIVoiceControl"

echo ""
echo "📱 App Bundle Information:"
echo "Path: $APP_PATH"
if [[ -d "$APP_PATH" ]]; then
    echo "✅ App bundle exists"
    
    # Check Info.plist
    INFO_PLIST="$APP_PATH/Contents/Info.plist"
    if [[ -f "$INFO_PLIST" ]]; then
        echo "✅ Info.plist exists"
        echo "🔍 Checking NSMicrophoneUsageDescription:"
        /usr/libexec/PlistBuddy -c "Print :NSMicrophoneUsageDescription" "$INFO_PLIST" 2>/dev/null || echo "❌ NSMicrophoneUsageDescription NOT found"
    else
        echo "❌ Info.plist NOT found"
    fi
    
    # Check code signature
    echo ""
    echo "🔐 Code Signature:"
    codesign -dv "$APP_PATH" 2>&1 | head -5
    
    # Check entitlements
    echo ""
    echo "📜 Entitlements:"
    codesign -d --entitlements - "$APP_PATH" 2>/dev/null | grep -A2 -B2 microphone || echo "❌ No microphone entitlement found"
    
else
    echo "❌ App bundle NOT found"
fi

echo ""
echo "🎤 Current TCC status:"
tccutil reset Microphone "$BUNDLE_ID" 2>/dev/null && echo "✅ Reset microphone permission" || echo "⚠️  Could not reset"

echo ""
echo "🚀 Try launching app with direct permission request..."