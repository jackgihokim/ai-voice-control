#!/bin/bash

# Fix Info.plist after build - handles multiple possible build locations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Function to fix Info.plist for a given app path
fix_infoplist() {
    local APP_PATH="$1"
    local PLIST_PATH="$APP_PATH/Contents/Info.plist"
    
    if [[ ! -f "$PLIST_PATH" ]]; then
        echo "⚠️ Info.plist not found at: $PLIST_PATH"
        return 1
    fi
    
    echo "🔧 Fixing Info.plist at: $PLIST_PATH"
    
    # Check if permissions are already present
    if grep -q "NSMicrophoneUsageDescription" "$PLIST_PATH"; then
        echo "✅ Permissions already present in: $PLIST_PATH"
        return 0
    fi
    
    # Add required keys before </dict>
    sed -i '' '/<\/dict>/i\
	<key>LSUIElement</key>\
	<true/>\
	<key>NSMicrophoneUsageDescription</key>\
	<string>AI Voice Control needs microphone access to recognize voice commands and enable hands-free interaction with your applications.</string>\
	<key>NSSpeechRecognitionUsageDescription</key>\
	<string>AI Voice Control uses speech recognition to convert your voice commands into text for application control.</string>\
	<key>NSAppleEventsUsageDescription</key>\
	<string>AI Voice Control needs automation permission to control terminal applications and execute voice commands.</string>
' "$PLIST_PATH"
    
    echo "🔐 Re-signing app: $APP_PATH"
    codesign --force --deep --sign - "$APP_PATH"
    
    echo "✅ Fixed and re-signed: $APP_PATH"
    return 0
}

echo "🔍 Looking for AIVoiceControl.app bundles..."

# Find all possible AIVoiceControl.app locations
find "$PROJECT_ROOT" -name "AIVoiceControl.app" -type d 2>/dev/null | while read APP_PATH; do
    echo "📱 Found app bundle: $APP_PATH"
    fix_infoplist "$APP_PATH"
done

echo "🎯 Specifically checking common Xcode build locations..."

# Check specific common locations
COMMON_PATHS=(
    "$PROJECT_ROOT/DerivedData/AIVoiceControl/Build/Products/Debug/AIVoiceControl.app"
    "$PROJECT_ROOT/DerivedData/Build/Products/Debug/AIVoiceControl.app"
    "$PROJECT_ROOT/build/Debug/AIVoiceControl.app"
)

for APP_PATH in "${COMMON_PATHS[@]}"; do
    if [[ -d "$APP_PATH" ]]; then
        fix_infoplist "$APP_PATH"
    fi
done

echo "🏁 Info.plist fix complete!"