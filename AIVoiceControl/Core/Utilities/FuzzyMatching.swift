import Foundation

struct FuzzyMatching {
    
    // MARK: - Configuration
    
    /// 유사도 매칭 임계값 (0.0 ~ 1.0)
    static let defaultSimilarityThreshold: Double = 0.8
    
    /// 웨이크 워드 길이 제한 (성능 최적화)
    static let minWakeWordLength: Int = 2
    static let maxWakeWordLength: Int = 10  // 웨이크 워드 전용으로 최적화
    
    /// 한국어 발음 변형 매핑
    private static let koreanVariations: [Character: Set<Character>] = [
        // ㅋ ↔ ㄱ 혼동 (무성음 ↔ 유성음)
        "ㅋ": ["ㄱ", "ㅋ"],
        "ㄱ": ["ㄱ", "ㅋ"],
        
        // ㅌ ↔ ㄷ 혼동
        "ㅌ": ["ㄷ", "ㅌ"],
        "ㄷ": ["ㄷ", "ㅌ"],
        
        // ㅍ ↔ ㅂ 혼동
        "ㅍ": ["ㅂ", "ㅍ"],
        "ㅂ": ["ㅂ", "ㅍ"],
        
        // ㅊ ↔ ㅈ 혼동
        "ㅊ": ["ㅈ", "ㅊ"],
        "ㅈ": ["ㅈ", "ㅊ"],
        
        // ㅎ ↔ ㅇ 혼동 (무성음 ↔ 유성음)
        "ㅎ": ["ㅇ", "ㅎ"],
        "ㅇ": ["ㅇ", "ㅎ"],
    ]
    
    /// 영어 발음 변형 매핑 (한국어 화자 특성)
    private static let englishVariations: [Character: Set<Character>] = [
        // L ↔ R 혼동
        "l": ["l", "r"],
        "r": ["l", "r"],
        "L": ["L", "R"],
        "R": ["L", "R"],
        
        // F ↔ P 혼동
        "f": ["f", "p"],
        "p": ["f", "p"],
        "F": ["F", "P"],
        "P": ["F", "P"],
        
        // V ↔ B 혼동
        "v": ["v", "b"],
        "b": ["v", "b"],
        "V": ["V", "B"],
        "B": ["V", "B"],
        
        // TH → S/T 혼동
        "s": ["s", "t"],
        "t": ["s", "t"],
        "S": ["S", "T"],
        "T": ["S", "T"],
    ]
    
    // MARK: - Public Methods
    
    /// 두 문자열의 유사도를 계산합니다
    /// - Parameters:
    ///   - source: 비교할 첫 번째 문자열
    ///   - target: 비교할 두 번째 문자열
    ///   - threshold: 유사도 임계값 (기본값: 0.8)
    /// - Returns: 유사도 점수 (0.0 ~ 1.0)
    static func calculateSimilarity(
        source: String,
        target: String,
        threshold: Double = defaultSimilarityThreshold
    ) -> Double {
        guard !source.isEmpty && !target.isEmpty else { return 0.0 }
        
        // 웨이크 워드 길이 제한 적용 (성능 최적화)
        guard source.count >= minWakeWordLength && source.count <= maxWakeWordLength &&
              target.count >= minWakeWordLength && target.count <= maxWakeWordLength else {
            return 0.0
        }
        
        // 길이 차이가 너무 크면 조기 종료 (50% 이상 차이)
        let lengthDiff = abs(source.count - target.count)
        let maxLength = max(source.count, target.count)
        if Double(lengthDiff) / Double(maxLength) > 0.5 {
            return 0.0
        }
        
        let distance = levenshteinDistance(source: source, target: target)
        let similarity = 1.0 - (Double(distance) / Double(maxLength))
        
        return similarity
    }
    
    /// 웨이크 워드가 텍스트와 매칭되는지 확인합니다
    /// - Parameters:
    ///   - wakeWord: 찾을 웨이크 워드
    ///   - text: 검색할 텍스트
    ///   - threshold: 유사도 임계값
    /// - Returns: 매칭 성공 여부와 유사도 점수
    static func matchWakeWord(
        wakeWord: String,
        in text: String,
        threshold: Double = defaultSimilarityThreshold
    ) -> (matched: Bool, similarity: Double) {
        let cleanWakeWord = wakeWord.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanWakeWord.isEmpty && !cleanText.isEmpty else {
            return (false, 0.0)
        }
        
        // 웨이크 워드 전용 길이 제한 적용 (2-10자 최적화)
        guard cleanText.count >= minWakeWordLength && cleanText.count <= maxWakeWordLength else {
            return (false, 0.0)
        }
        
        // 1. 정확한 매칭 확인 (가장 높은 우선순위)
        if cleanText.contains(cleanWakeWord) {
            return (true, 1.0)
        }
        
        // 2. 단어 단위로 분리하여 매칭 확인
        let words = cleanText.split(separator: " ").map { String($0) }
        
        for word in words {
            let similarity = calculateSimilarity(source: cleanWakeWord, target: word, threshold: threshold)
            if similarity >= threshold {
                return (true, similarity)
            }
        }
        
        // 3. 전체 텍스트와의 부분 매칭 확인
        let overallSimilarity = calculatePartialSimilarity(wakeWord: cleanWakeWord, text: cleanText, threshold: threshold)
        if overallSimilarity >= threshold {
            return (true, overallSimilarity)
        }
        
        return (false, overallSimilarity)
    }
    
    // MARK: - Private Methods
    
    /// Levenshtein Distance 알고리즘 구현 (최적화된 버전)
    /// - Parameters:
    ///   - source: 첫 번째 문자열
    ///   - target: 두 번째 문자열
    /// - Returns: 편집 거리
    private static func levenshteinDistance(source: String, target: String) -> Int {
        let sourceArray = Array(source)
        let targetArray = Array(target)
        let sourceLength = sourceArray.count
        let targetLength = targetArray.count
        
        // 빈 문자열 처리
        if sourceLength == 0 { return targetLength }
        if targetLength == 0 { return sourceLength }
        
        // 메모리 최적화: 2개 행만 사용
        var previousRow = Array(0...targetLength)
        var currentRow = Array(repeating: 0, count: targetLength + 1)
        
        for i in 1...sourceLength {
            currentRow[0] = i
            
            for j in 1...targetLength {
                let cost = areCharactersSimilar(sourceArray[i-1], targetArray[j-1]) ? 0 : 1
                
                currentRow[j] = min(
                    currentRow[j-1] + 1,      // insertion
                    previousRow[j] + 1,       // deletion
                    previousRow[j-1] + cost   // substitution
                )
            }
            
            // 행 교체
            swap(&previousRow, &currentRow)
        }
        
        return previousRow[targetLength]
    }
    
    /// 두 문자가 유사한지 확인 (발음 변형 고려)
    /// - Parameters:
    ///   - char1: 첫 번째 문자
    ///   - char2: 두 번째 문자
    /// - Returns: 유사한 문자 여부
    private static func areCharactersSimilar(_ char1: Character, _ char2: Character) -> Bool {
        // 정확히 같은 문자
        if char1 == char2 {
            return true
        }
        
        // 한국어 발음 변형 확인
        if let variations = koreanVariations[char1], variations.contains(char2) {
            return true
        }
        
        // 영어 발음 변형 확인
        if let variations = englishVariations[char1], variations.contains(char2) {
            return true
        }
        
        return false
    }
    
    /// 부분 문자열 매칭을 위한 유사도 계산 (슬라이딩 윈도우 최적화)
    /// - Parameters:
    ///   - wakeWord: 웨이크 워드
    ///   - text: 전체 텍스트
    ///   - threshold: 임계값
    /// - Returns: 최고 유사도
    private static func calculatePartialSimilarity(
        wakeWord: String,
        text: String,
        threshold: Double
    ) -> Double {
        let wakeWordLength = wakeWord.count
        let textLength = text.count
        
        guard wakeWordLength > 0 && textLength >= wakeWordLength else {
            return 0.0
        }
        
        var maxSimilarity: Double = 0.0
        
        // 최적화된 슬라이딩 윈도우: maxWakeWordLength(10자) 제한 적용
        let windowSize = min(maxWakeWordLength, max(wakeWordLength, minWakeWordLength))
        
        // 윈도우 크기 이내에서만 슬라이딩
        let maxStartIndex = max(0, textLength - windowSize)
        
        for i in 0...maxStartIndex {
            let endIndex = min(i + windowSize, textLength)
            let startIndex = text.index(text.startIndex, offsetBy: i)
            let actualEndIndex = text.index(text.startIndex, offsetBy: endIndex)
            let substring = String(text[startIndex..<actualEndIndex])
            
            // 길이 제한 내의 부분 문자열만 처리
            if substring.count >= minWakeWordLength && substring.count <= maxWakeWordLength {
                let similarity = calculateSimilarity(source: wakeWord, target: substring, threshold: threshold)
                maxSimilarity = max(maxSimilarity, similarity)
                
                // 임계값 이상이면 조기 종료 (성능 최적화)
                if similarity >= threshold {
                    return similarity
                }
            }
        }
        
        return maxSimilarity
    }
}

// MARK: - Extensions

extension FuzzyMatching {
    
    /// 디버깅을 위한 상세한 매칭 정보
    struct MatchingResult {
        let matched: Bool
        let similarity: Double
        let matchType: MatchType
        let matchedWord: String?
        
        enum MatchType {
            case exact          // 정확한 매칭
            case wordLevel      // 단어 레벨 유사 매칭
            case partial        // 부분 문자열 매칭
            case none          // 매칭 없음
        }
    }
    
    /// 상세한 매칭 결과를 반환하는 메서드 (디버깅용)
    static func detailedMatch(
        wakeWord: String,
        in text: String,
        threshold: Double = defaultSimilarityThreshold
    ) -> MatchingResult {
        let cleanWakeWord = wakeWord.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 정확한 매칭
        if cleanText.contains(cleanWakeWord) {
            return MatchingResult(matched: true, similarity: 1.0, matchType: .exact, matchedWord: cleanWakeWord)
        }
        
        // 단어 레벨 매칭
        let words = cleanText.split(separator: " ").map { String($0) }
        for word in words {
            let similarity = calculateSimilarity(source: cleanWakeWord, target: word, threshold: threshold)
            if similarity >= threshold {
                return MatchingResult(matched: true, similarity: similarity, matchType: .wordLevel, matchedWord: word)
            }
        }
        
        // 부분 매칭
        let partialSimilarity = calculatePartialSimilarity(wakeWord: cleanWakeWord, text: cleanText, threshold: threshold)
        if partialSimilarity >= threshold {
            return MatchingResult(matched: true, similarity: partialSimilarity, matchType: .partial, matchedWord: nil)
        }
        
        return MatchingResult(matched: false, similarity: partialSimilarity, matchType: .none, matchedWord: nil)
    }
}