#!/bin/bash

# 메뉴바 모드로 전환하는 스크립트

echo "🔄 앱을 메뉴바 모드로 전환합니다..."

# Info.plist에서 LSUIElement 활성화
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLIST_PATH="$PROJECT_ROOT/AIVoiceControl/Info.plist"

sed -i '' 's/<!-- <key>LSUIElement<\/key>/<key>LSUIElement<\/key>/' "$PLIST_PATH"
sed -i '' 's/<true\/> -->/<true\/>/' "$PLIST_PATH"

echo "✅ 메뉴바 모드로 전환 완료"
echo "💡 이제 앱을 다시 빌드하면 메뉴바 앱으로 실행됩니다"