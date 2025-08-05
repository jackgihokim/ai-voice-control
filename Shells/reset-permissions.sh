#!/bin/bash

# Reset TCC permissions for development
# This script helps during development when permissions get confused

BUNDLE_ID="com.jack-kim-dev.AIVoiceControl"

echo "🧹 Resetting TCC permissions for $BUNDLE_ID..."

# Kill the app first
pkill -f AIVoiceControl

# Reset TCC permissions (requires System Integrity Protection to be disabled or admin privileges)
echo "ℹ️  Note: You may need to manually reset permissions in System Settings"
echo "   Go to: System Settings > Privacy & Security > Microphone"
echo "   Remove AIVoiceControl from the list if present"

# Reset app preferences
defaults delete "$BUNDLE_ID" 2>/dev/null || echo "No preferences to reset"

# Clear app cache
rm -rf ~/Library/Caches/"$BUNDLE_ID" 2>/dev/null
rm -rf ~/Library/Application\ Support/"$BUNDLE_ID" 2>/dev/null

echo "✅ Reset complete. Please:"
echo "   1. Go to System Settings > Privacy & Security > Microphone"
echo "   2. Remove any existing AIVoiceControl entries"
echo "   3. Rebuild and run the app"
echo "   4. Test permission request"