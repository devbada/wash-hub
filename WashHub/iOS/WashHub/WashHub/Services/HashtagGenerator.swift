import Foundation
import NaturalLanguage

/// WashHub 해시태그 자동 생성기
///
/// - 본문(content), 차량 정보, 세차 방식 등 컨텍스트를 받아서 도메인 사전 매칭
/// - iOS NaturalLanguage 의 NLTokenizer 로 한국어 단어 분리
/// - 결과는 우선순위순(차량 → 세차방식 → 본문 키워드) + 중복 제거 + 최대 N개
///
/// 외부 API 호출 없이 로컬에서 즉시 계산되므로 본문 입력 중 실시간 호출 가능
/// (성능 부담 없음 — 평균 1ms 이하)
enum HashtagGenerator {

    /// 추천 해시태그 생성
    /// - Parameters:
    ///   - content: 사용자 본문
    ///   - washMethod: "셀프 손세차" 등 사용자 입력 세차 방식
    ///   - car: 선택된 차량 (모델명/색상/연식)
    ///   - maxCount: 최대 반환 개수 (기본 7)
    static func generate(
        content: String?,
        washMethod: String? = nil,
        car: FeedCar? = nil,
        maxCount: Int = 7
    ) -> [String] {
        var ordered: [String] = []
        var seen: Set<String> = []

        // 결과에 추가하면서 중복 제거
        func add(_ tag: String) {
            let key = tag.lowercased()
            guard !seen.contains(key) else { return }
            seen.insert(key)
            ordered.append(tag)
        }

        // ① 차량 정보 — 가장 식별성 높음 (별명 우선)
        if let car = car {
            for tag in HashtagDictionary.tagsFromCar(
                model: car.carModel,
                color: car.carColor,
                year: car.carYear,
                nickname: car.nickname
            ) {
                add(tag)
            }
        }

        // ② 세차 방식
        if let method = washMethod, !method.isEmpty {
            matchAllKeywords(in: method, addTo: &ordered, seen: &seen)
        }

        // ③ 본문 키워드 매칭
        if let text = content, !text.isEmpty {
            matchAllKeywords(in: text, addTo: &ordered, seen: &seen)
        }

        // ④ 본문에 명시된 #해시태그 직접 캡처 (사용자가 입력한 것)
        if let text = content, !text.isEmpty {
            for explicit in extractExplicitHashtags(from: text) {
                add(explicit)
            }
        }

        return Array(ordered.prefix(maxCount))
    }

    // MARK: - 키워드 매칭 (substring 기반 — "아반떼입니다" 같은 결합형 캐치)

    /// 텍스트 안에서 사전 키워드를 모두 찾아서 ordered 에 추가
    /// - 2글자+ 키: 단순 substring 매칭 (조사/접미사 결합형도 잡음. 예: "왁스했어요" → #왁스)
    /// - 1글자 키: NLTokenizer로 단어 분리 + 조사 제거 후 정확 매칭 (예: "비싸다"에서 #비 false-positive 방지)
    private static func matchAllKeywords(
        in text: String,
        addTo ordered: inout [String],
        seen: inout Set<String>
    ) {
        let lowered = text.lowercased()

        // 2글자+ 키: substring 매칭
        for (key, tags) in HashtagDictionary.mappings where key.count >= 2 {
            if lowered.contains(key) {
                for tag in tags {
                    let dedupeKey = tag.lowercased()
                    if !seen.contains(dedupeKey) {
                        seen.insert(dedupeKey)
                        ordered.append(tag)
                    }
                }
            }
        }

        // 1글자 키: 토큰화 후 정확 매칭 (false positive 방지)
        let oneCharTokens = tokenize(text).map { $0.lowercased() }
        let oneCharKeys = HashtagDictionary.mappings.filter { $0.key.count == 1 }
        for (key, tags) in oneCharKeys where oneCharTokens.contains(key) {
            for tag in tags {
                let dedupeKey = tag.lowercased()
                if !seen.contains(dedupeKey) {
                    seen.insert(dedupeKey)
                    ordered.append(tag)
                }
            }
        }
    }

    // MARK: - Tokenization (1글자 키 매칭 시에만 사용)

    /// 한국어 텍스트를 단어 단위로 분리 + 조사 제거 (1글자 단어 포함 — 1글자 키 매칭용)
    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let raw = String(text[range])
            let cleaned = stripParticles(raw)
            if cleaned.count >= 1 && cleaned.count <= 15 {
                tokens.append(cleaned)
            }
            return true
        }
        return tokens
    }

    /// 한국어 조사/어미를 단순 규칙으로 제거 (간이 형태소)
    private static func stripParticles(_ word: String) -> String {
        let particles = [
            "입니다", "이에요", "이었습니다", "였습니다", "이었어요", "였어요",
            "으로", "에서", "에게", "한테", "까지", "부터",
            "이다", "이고", "하고", "라고",
            "은", "는", "이", "가", "을", "를", "에", "의", "도", "만", "와", "과", "랑"
        ]
        // 길이가 긴 조사부터 시도 (예: "입니다"가 "다"보다 우선)
        let sorted = particles.sorted { $0.count > $1.count }
        for particle in sorted {
            if word.hasSuffix(particle) && word.count > particle.count {
                return String(word.dropLast(particle.count))
            }
        }
        return word
    }

    /// 본문에서 사용자가 직접 입력한 #해시태그 추출 (예: "오늘 #셀프세차 다녀옴")
    private static func extractExplicitHashtags(from text: String) -> [String] {
        var result: [String] = []
        // 정규식 — # 다음 한글/영문/숫자/언더바 1글자 이상
        let pattern = "#[가-힣A-Za-z0-9_]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            let tag = nsText.substring(with: match.range)
            if tag.count >= 2 && tag.count <= 30 {
                result.append(tag)
            }
        }
        return result
    }
}
