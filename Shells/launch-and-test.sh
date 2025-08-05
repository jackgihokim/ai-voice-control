#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="$PROJECT_ROOT/DerivedData/AIVoiceControl/Build/Products/Debug/AIVoiceControl.app"
BUNDLE_ID="com.jack-kim-dev.AIVoiceControl"

echo "🧹 Cleaning up previous instances..."
pkill -f AIVoiceControl

echo "🔄 Resetting all permissions..."
tccutil reset All "$BUNDLE_ID" 2>/dev/null

echo "🚀 Launching app directly from Finder..."
# This simulates user double-clicking the app
open "$APP_PATH"

echo "✅ App launched. Now:"
echo "1. Go to app Settings > Permissions > Microphone"
echo "2. Click 'Request Permission' or 'Test Mic Request'"
echo "3. You should see a system dialog asking for microphone permission"
echo ""
echo "If you still get 'denied', try:"
echo "• Quit the app completely (right-click menu bar icon > Quit)"
echo "• Run this script again"
echo "• Make sure no other instances of the app are running"