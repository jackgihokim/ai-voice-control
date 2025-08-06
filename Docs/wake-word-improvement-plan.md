# 웨이크 워드 인식률 개선 계획

## 📊 현재 상황 분석

### 현재 문제점
- 웨이크 워드 인식률이 일정하지 않음
- 발음 변형에 대한 대응 부족 (예: "클로드" → "글로드", "크로드")
- 정확한 발음만 인식하는 엄격한 매칭
- 배경 소음이나 말하는 속도에 민감함

### 현재 매칭 방식
```swift
// 현재: 단순 exact match + contains 방식
let words = lowercasedText.split(separator: " ").map { String($0) }
if words.contains(lowercasedWakeWord) {
    return app
}
// Fall back to contains check
if lowercasedText.contains(lowercasedWakeWord) {
    return app
}
```

## 🎯 개선 목표

1. **인식률 향상**: 현재 70-80% → 90-95% 목표
2. **발음 변형 대응**: 한국어 특성 고려한 유연한 매칭
3. **False Positive 최소화**: 정확도 유지하면서 recall 개선
4. **성능 최적화**: 응답시간 150ms 이하 유지

## 📈 3단계 구현 로드맵

---

## 1️⃣ 1단계: 안전한 매칭 알고리즘 개선 (현재 구현)

### 🎯 목표
- **위험도**: 낮음
- **예상 개선**: 인식률 15-20% 향상
- **성능 영향**: CPU +30%, 메모리 +50MB, 응답시간 +100ms

### 🔧 구현 내용

#### A. Levenshtein Distance 기반 유사도 매칭
```swift
// 새로운 매칭 로직
func calculateSimilarity(word1: String, word2: String) -> Double {
    let distance = levenshteinDistance(word1, word2)
    let maxLength = max(word1.count, word2.count)
    return 1.0 - (Double(distance) / Double(maxLength))
}

// 임계값: 0.8 이상이면 매칭 성공
let similarityThreshold = 0.8
```

#### B. 한국어 발음 변형 매핑
```swift
let koreanVariations: [Character: [Character]] = [
    'ㅋ': ['ㄱ', 'ㅋ'],           // "클로드" ↔ "글로드"
    'ㅌ': ['ㄷ', 'ㅌ'],           // "챗" ↔ "쳇"
    'ㅍ': ['ㅂ', 'ㅍ'],           // "파이어폭스" ↔ "바이어폭스"
    'ㅊ': ['ㅈ', 'ㅊ'],           // "챗GPT" ↔ "잣GPT"
]
```

#### C. 신뢰도 기반 필터링
```swift
// 품질 검증 기준
- 웨이크 워드 길이: 2-15자 이내
- 유사도 점수: 0.8 이상
- 음성 길이: 0.5-5초 이내
- 볼륨 레벨: 최소 임계값 이상
```

### 📁 파일 구조
```
Core/Utilities/
├── FuzzyMatching.swift          # 새로 생성
│   ├── LevenshteinDistance 알고리즘
│   ├── 한국어 발음 변형 매핑
│   └── 유사도 계산 유틸리티
│
Features/VoiceRecognition/
├── WakeWordDetector.swift       # 수정
│   └── 개선된 detectWakeWord() 메서드
```

### 📊 예상 성능 영향
- **CPU 사용량**: 현재 대비 +30% (5% → 6.5%)
- **메모리 사용량**: +50MB (250MB → 300MB)
- **응답 시간**: +100ms (300ms → 400ms)
- **배터리 영향**: 거의 없음 (<5%)

---

## 2️⃣ 2단계: 음성 처리 최적화 (차후 구현)

### 🎯 목표
- **위험도**: 중간
- **예상 개선**: 인식률 20-30% 추가 향상
- **성능 영향**: CPU +150%, 메모리 +400MB

### 🔧 구현 내용

#### A. 이중 언어 모델 동시 실행
```swift
class DualLanguageRecognizer {
    private let koreanRecognizer: SFSpeechRecognizer
    private let englishRecognizer: SFSpeechRecognizer
    
    func startDualRecognition() {
        // 한국어와 영어 동시 처리
        // 교차 검증을 통한 정확도 향상
    }
}
```

#### B. Voice Isolation 강화
```swift
// 고급 노이즈 제거
- 주파수 필터링
- 볼륨 정규화
- 에코 제거
- 실시간 SNR 모니터링
```

#### C. 실시간 피드백 시스템
```swift
// UI 개선
- 음성 레벨 실시간 표시
- 웨이크 워드 인식 상태 표시
- 발음 가이드 제공
- 인식 실패 이유 안내
```

### 📊 예상 성능 영향
- **CPU 사용량**: +150% (6.5% → 16%)
- **메모리 사용량**: +400MB (300MB → 700MB)
- **응답 시간**: +300ms (400ms → 700ms)
- **배터리 영향**: -20-30% 수명

---

## 3️⃣ 3단계: 학습 기반 개선 (차후 구현)

### 🎯 목표
- **위험도**: 높음
- **예상 개선**: 인식률 95%+ 달성
- **성능 영향**: 상황에 따라 다름

### 🔧 구현 내용

#### A. 개인화 학습 시스템
```swift
class PersonalizedWakeWordLearner {
    // 사용자별 발음 패턴 학습
    // 실패 패턴 분석 및 개선
    // 동적 임계값 조정
}
```

#### B. 컨텍스트 인식
```swift
// 상황별 최적화
- 시간대별 사용 패턴
- 앱별 사용 빈도
- 이전 성공 패턴 우선 순위
```

#### C. ML 기반 고급 알고리즘
```swift
// Core ML 활용
- 음성 특성 벡터화
- 개인별 모델 학습
- 연속 학습 (Continual Learning)
```

---

## ⚙️ 구현 우선순위

### 🟢 1단계 (현재 구현) - 필수
- ✅ 안전하고 검증된 방법
- ✅ 성능 영향 최소
- ✅ 즉시 효과 확인 가능

### 🟡 2단계 - 선택적
- ⚠️ 사용자 피드백 후 결정
- ⚠️ 성능 vs 정확도 트레이드오프
- ⚠️ A/B 테스트 필요

### 🔴 3단계 - 고급
- 🚫 복잡도 매우 높음
- 🚫 별도 프로젝트 수준
- 🚫 충분한 데이터 필요

---

## 📊 성공 지표

### 정량적 지표
- **인식률**: 70-80% → 90-95%
- **응답시간**: 300ms → 400ms 이하 유지
- **False Positive**: 5% 이하
- **CPU 사용량**: 10% 이하 유지

### 정성적 지표
- **사용자 만족도**: 개선 체감도
- **안정성**: 크래시 없음
- **배터리 수명**: 큰 영향 없음

---

## 🧪 테스트 계획

### 단위 테스트
```swift
func testFuzzyMatching() {
    // "클로드" vs "글로드" → 매칭 성공
    // "클로드" vs "apple" → 매칭 실패
    // 경계값 테스트
}
```

### 통합 테스트
```swift
func testWakeWordRecognition() {
    // 실제 음성 입력 시뮬레이션
    // 다양한 발음 패턴 테스트
    // 성능 측정
}
```

### 사용자 테스트
- 베타 테스터 그룹 대상
- 실제 사용 환경에서 테스트
- 피드백 수집 및 개선

---

## 📝 구현 시 주의사항

### 성능 최적화
- **조기 종료**: 임계값 미달시 빠른 리턴
- **캐싱**: 계산 결과 재사용
- **배치 처리**: 여러 웨이크 워드 동시 처리

### 품질 보장
- **점진적 배포**: 단계별 A/B 테스트
- **롤백 계획**: 문제시 즉시 이전 버전으로 복원
- **모니터링**: 실시간 성능 지표 추적

### 사용자 경험
- **설정 옵션**: 민감도 조절 가능
- **피드백**: 인식 결과 표시
- **가이드**: 올바른 사용법 안내

---

## 💡 결론

1단계 구현을 통해 **안전하고 점진적인 개선**을 시작하고, 사용자 피드백을 바탕으로 2단계, 3단계 진행 여부를 결정하는 것이 최적의 전략입니다.

**현재 목표**: 1단계 완료 후 인식률 15-20% 개선 달성! 🎯