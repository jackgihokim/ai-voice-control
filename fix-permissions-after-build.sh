#!/bin/bash

# Post-build script to fix permissions for development
# This ensures permission dialogs work even when building from Xcode

APP_PATH="$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app"

echo "🔧 Applying permission fixes to: $APP_PATH"

if [[ -d "$APP_PATH" ]]; then
    # Remove quarantine attributes
    xattr -cr "$APP_PATH" 2>/dev/null || true
    
    # Apply ad-hoc code signing to ensure permission dialogs work
    codesign --force --deep --sign - "$APP_PATH" 2>/dev/null || true
    
    echo "✅ Permission fixes applied successfully"
else
    echo "❌ App not found at: $APP_PATH"
fi