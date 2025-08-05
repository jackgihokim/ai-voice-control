#!/bin/bash

# 일반 앱 모드로 전환하는 스크립트 (권한 요청용)

echo "🔄 앱을 일반 모드로 전환합니다..."

# Info.plist에서 LSUIElement 비활성화 (중복 주석 방지)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLIST_PATH="$PROJECT_ROOT/AIVoiceControl/Info.plist"

sed -i '' 's/<!-- <key>LSUIElement<\/key>/<key>LSUIElement<\/key>/' "$PLIST_PATH"
sed -i '' 's/<true\/> -->/<true\/>/' "$PLIST_PATH"
sed -i '' 's/<key>LSUIElement<\/key>/<!-- <key>LSUIElement<\/key>/' "$PLIST_PATH"
sed -i '' 's/<true\/>/<true\/> -->/' "$PLIST_PATH"

echo "✅ 일반 모드로 전환 완료"
echo "💡 이제 앱을 다시 빌드하면 권한 다이얼로그가 정상적으로 나타납니다"