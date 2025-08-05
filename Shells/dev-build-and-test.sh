#!/bin/bash

# Development build and test script
# This script handles all the permission issues during development

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="$PROJECT_ROOT/DerivedData/AIVoiceControl/Build/Products/Debug/AIVoiceControl.app"
BUNDLE_ID="com.jack-kim-dev.AIVoiceControl"

echo "🚀 AI Voice Control Development Build & Test Script"
echo "=================================================="

# Step 1: Kill existing instances
echo ""
echo "1️⃣ Killing existing instances..."
pkill -f AIVoiceControl

# Step 2: Reset permissions
echo ""
echo "2️⃣ Resetting all permissions..."
tccutil reset All "$BUNDLE_ID" 2>/dev/null
tccutil reset Microphone "$BUNDLE_ID" 2>/dev/null
tccutil reset SpeechRecognition "$BUNDLE_ID" 2>/dev/null

# Step 3: Clean build
echo ""
echo "3️⃣ Building app..."
cd "$PROJECT_ROOT"
xcodebuild -project AIVoiceControl.xcodeproj -scheme AIVoiceControl -configuration Debug clean build

# Step 4: Apply Gatekeeper fix
if [[ -d "$APP_PATH" ]]; then
    echo ""
    echo "4️⃣ Applying Gatekeeper fixes..."
    
    # Remove quarantine attributes
    xattr -cr "$APP_PATH"
    
    # Apply ad-hoc code signing
    codesign --force --deep --sign - "$APP_PATH"
    
    echo "✅ Gatekeeper fixes applied"
else
    echo "❌ App not found at: $APP_PATH"
    exit 1
fi

# Step 5: Launch app
echo ""
echo "5️⃣ Launching app..."
open "$APP_PATH"

echo ""
echo "✅ Development build complete!"
echo ""
echo "📝 Testing Instructions:"
echo "1. Click the menu bar icon"
echo "2. Click Settings > Permissions"
echo "3. Request permissions as needed"
echo "4. The permission dialogs should now appear"
echo ""
echo "💡 If permission dialogs still don't appear:"
echo "   1. Run: ./Shells/switch-to-regular.sh"
echo "   2. Rebuild and test"
echo "   3. After permissions granted, run: ./Shells/switch-to-menubar.sh"