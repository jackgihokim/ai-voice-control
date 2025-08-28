//
//  KoreanPunctuationHelper.swift
//  AIVoiceControl
//
//  Created by Claude on 2025-08-26.
//

import Foundation

/// 한국어 종결어미를 분석하여 적절한 구두점을 추가하는 헬퍼 클래스
class KoreanPunctuationHelper {
    
    // MARK: - Punctuation Style
    enum PunctuationStyle {
        case conservative  // 확실한 경우만 구두점 추가
        case aggressive    // 적극적으로 구두점 추가
        case none         // 구두점 추가 안함
    }
    
    // MARK: - 종결어미 패턴 정의
    
    /// 의문형 종결어미 (물음표 추가)
    private static let questionEndings = [
        // 격식체
        "습니까", "입니까", "십니까", "시겠습니까",
        // 비격식 존댓말
        "나요", "까요", "을까요", "ㄹ까요", "는가요", "던가요",
        "은가요", "인가요", "일까요", "죠", "지요",
        // 반말 의문형
        "니", "냐", "는가", "을까", "ㄹ까", "야", "랴",
        "던가", "는지", "은지", "을지", "ㄹ지"
    ]
    
    /// 평서형 종결어미 (마침표 추가)
    private static let statementEndings = [
        // 격식체
        "습니다", "입니다", "됩니다", "었습니다", "겠습니다",
        // 비격식 존댓말
        "어요", "아요", "예요", "이에요", "에요", "이예요",
        "네요", "더라고요", "더군요", "던데요",
        // 발견/감탄
        "는구나", "는구려", "더라", "더군", "로구나",
        // 반말
        "다", "어", "아", "야", "지", "거든", "는데", "은데"
    ]
    
    /// 명령형 종결어미 (마침표 추가)
    private static let commandEndings = [
        // 높임 명령
        "세요", "으세요", "십시오", "시오", "소서",
        // 일반 명령
        "어라", "아라", "려무나", "거라", "렴", "려",
        // 부탁/요청
        "어줘", "아줘", "줘", "주세요", "주십시오", "주시겠어요"
    ]
    
    /// 감탄형 종결어미 (느낌표 추가)
    private static let exclamationEndings = [
        "구나", "는군", "로군", "는걸", "네",
        "구려", "구먼", "어라", "도다"
    ]
    
    /// 의문사 (문장에 포함되면 높은 확률로 의문문)
    private static let questionWords = [
        "뭐", "무엇", "무슨", "뭘", "뭔",
        "누구", "누가", "누굴", "누구를",
        "언제", "어디", "어디서", "어디로", "어디에",
        "어떻게", "어떤", "어째서",
        "왜", "왠", "무얼", "얼마", "얼마나",
        "몇", "며칠", "몇시", "몇개"
    ]
    
    // MARK: - Public Methods
    
    /// 텍스트에 적절한 구두점을 추가
    static func addPunctuation(to text: String, style: PunctuationStyle = .conservative) -> String {
        // None 스타일이면 원본 그대로 반환
        guard style != .none else { return text }
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 빈 문자열이면 그대로 반환
        guard !trimmedText.isEmpty else { return text }
        
        // 이미 구두점이 있으면 그대로 반환
        if hasPunctuation(trimmedText) {
            return text
        }
        
        // Conservative 모드: 확실한 경우만 처리
        if style == .conservative {
            return addConservativePunctuation(to: trimmedText)
        }
        
        // Aggressive 모드: 적극적으로 처리
        return addAggressivePunctuation(to: trimmedText)
    }
    
    // MARK: - Private Methods
    
    /// 이미 구두점이 있는지 확인
    private static func hasPunctuation(_ text: String) -> Bool {
        let punctuations = [".", "?", "!", ",", ";", ":", "。", "？", "！"]
        for punctuation in punctuations {
            if text.hasSuffix(punctuation) {
                return true
            }
        }
        return false
    }
    
    /// Conservative 모드: 확실한 경우만 구두점 추가
    private static func addConservativePunctuation(to text: String) -> String {
        // 1. 의문사가 포함되어 있으면 물음표
        for word in questionWords {
            if text.contains(word) {
                return text + "?"
            }
        }
        
        // 2. 명확한 의문형 종결어미 확인 (긴 패턴부터)
        for ending in questionEndings.sorted(by: { $0.count > $1.count }) {
            if text.hasSuffix(ending) {
                return text + "?"
            }
        }
        
        // 3. 명확한 감탄형 종결어미 확인
        for ending in exclamationEndings.sorted(by: { $0.count > $1.count }) {
            if text.hasSuffix(ending) {
                return text + "!"
            }
        }
        
        // 4. 명령형 종결어미 확인
        for ending in commandEndings.sorted(by: { $0.count > $1.count }) {
            if text.hasSuffix(ending) {
                // "주세요"로 끝나면 부탁이므로 마침표
                if ending.contains("주") || ending.contains("세요") {
                    return text + "."
                }
                return text + "."
            }
        }
        
        // 5. 평서형 종결어미 확인
        for ending in statementEndings.sorted(by: { $0.count > $1.count }) {
            if text.hasSuffix(ending) {
                return text + "."
            }
        }
        
        // 6. 기본값: 구두점 추가하지 않음 (conservative)
        return text
    }
    
    /// Aggressive 모드: 적극적으로 구두점 추가
    private static func addAggressivePunctuation(to text: String) -> String {
        // Conservative 처리 먼저 시도
        let conservativeResult = addConservativePunctuation(to: text)
        
        // Conservative에서 구두점이 추가되었으면 그대로 반환
        if conservativeResult != text {
            return conservativeResult
        }
        
        // Aggressive 추가 처리
        
        // 짧은 단어나 감탄사
        let interjections = ["아", "어", "오", "우와", "와", "헐", "대박", "진짜", "정말"]
        for interjection in interjections {
            if text == interjection || text.hasPrefix(interjection + " ") {
                return text + "!"
            }
        }
        
        // 인사말
        let greetings = ["안녕", "안녕하세요", "안녕하십니까", "반갑습니다", "반가워"]
        for greeting in greetings {
            if text.contains(greeting) {
                return text + "."
            }
        }
        
        // 기본값: 마침표 추가 (aggressive)
        return text + "."
    }
    
    // MARK: - Helper Methods for Special Cases
    
    /// 애매한 종결어미 처리 (컨텍스트 필요한 경우)
    static func handleAmbiguousEnding(_ text: String) -> String? {
        // "어요/아요"는 평서문일 수도, 의문문일 수도 있음
        if text.hasSuffix("어요") || text.hasSuffix("아요") {
            // 존재 동사가 있으면 의문문 가능성 높음
            if text.contains("있어요") || text.contains("없어요") {
                // "있어요?" vs "있어요."
                // 문맥상 판단 어려우므로 nil 반환
                return nil
            }
        }
        
        return nil
    }
    
    /// 디버그용: 종결어미 타입 판단
    static func detectEndingType(_ text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 의문사 체크
        for word in questionWords {
            if trimmedText.contains(word) {
                return "의문문(의문사)"
            }
        }
        
        // 종결어미 체크 (긴 것부터)
        for ending in questionEndings.sorted(by: { $0.count > $1.count }) {
            if trimmedText.hasSuffix(ending) {
                return "의문문(종결어미: \(ending))"
            }
        }
        
        for ending in exclamationEndings.sorted(by: { $0.count > $1.count }) {
            if trimmedText.hasSuffix(ending) {
                return "감탄문(종결어미: \(ending))"
            }
        }
        
        for ending in commandEndings.sorted(by: { $0.count > $1.count }) {
            if trimmedText.hasSuffix(ending) {
                return "명령문(종결어미: \(ending))"
            }
        }
        
        for ending in statementEndings.sorted(by: { $0.count > $1.count }) {
            if trimmedText.hasSuffix(ending) {
                return "평서문(종결어미: \(ending))"
            }
        }
        
        return "미분류"
    }
}