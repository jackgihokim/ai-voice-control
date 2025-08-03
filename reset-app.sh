#!/bin/bash

# Reset script for AIVoiceControl
# This script helps reset the app state during development

echo "🧹 AIVoiceControl Reset Script"
echo "================================"

# 1. Kill any running instances
echo "1. Killing running instances..."
killall AIVoiceControl 2>/dev/null || echo "   No running instances found"

# 2. Delete UserDefaults
echo "2. Deleting UserDefaults..."
defaults delete com.jack-kim-dev.AIVoiceControl 2>/dev/null || echo "   No UserDefaults found"

# 3. Clean DerivedData
echo "3. Cleaning DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/AIVoiceControl-* 2>/dev/null
echo "   DerivedData cleaned"

# 4. Clean app caches
echo "4. Cleaning app caches..."
rm -rf ~/Library/Caches/com.jack-kim-dev.AIVoiceControl 2>/dev/null
echo "   Caches cleaned"

# 5. Reset Launch Services (optional - uncomment if needed)
# echo "5. Resetting Launch Services..."
# /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

echo ""
echo "✅ Reset complete!"
echo ""
echo "Next steps:"
echo "1. In Xcode: Product → Clean Build Folder (⇧⌘K)"
echo "2. Build and run the app (⌘R)"
echo ""
echo "Or run with reset flag:"
echo "   Open Product → Scheme → Edit Scheme"
echo "   Add argument: -reset-defaults"