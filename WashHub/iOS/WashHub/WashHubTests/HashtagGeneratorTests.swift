//
//  HashtagGeneratorTests.swift
//  WashHubTests
//
//  HashtagGenerator 단위 테스트
//  - 본문 substring 매칭 (조사/접미사 결합형 캐치)
//  - 차량 정보 우선순위
//  - 명시적 #해시태그 추출
//  - 중복 제거 + maxCount 제한
//

import Testing
@testable import WashHub

struct HashtagGeneratorTests {

    // MARK: - 본문 키워드 매칭

    @Test("본문에 '셀프세차'가 있으면 #셀프세차 태그가 생성된다")
    func generatesSelfWashFromContent() {
        let result = HashtagGenerator.generate(content: "오늘 셀프세차 다녀왔어요")
        #expect(result.contains("#셀프세차"))
    }

    @Test("'아반떼입니다' 처럼 조사가 붙어도 차량 모델 키워드를 잡는다")
    func matchesCarModelWithParticle() {
        let result = HashtagGenerator.generate(content: "제 차는 아반떼입니다")
        #expect(result.contains("#아반떼"))
    }

    @Test("'왁스했어요' 같은 결합형도 #왁스 태그를 잡는다 (substring 매칭)")
    func matchesCompoundWord() {
        let result = HashtagGenerator.generate(content: "오늘 왁스했어요")
        #expect(result.contains("#왁스"))
    }

    @Test("키워드가 없는 본문이면 빈 배열을 반환한다")
    func emptyForUnknownContent() {
        let result = HashtagGenerator.generate(content: "아무말 대잔치")
        #expect(result.isEmpty)
    }

    @Test("nil 본문이면 빈 배열을 반환한다")
    func emptyForNilContent() {
        let result = HashtagGenerator.generate(content: nil)
        #expect(result.isEmpty)
    }

    // MARK: - 차량 정보 우선순위

    @Test("차량 별명이 있으면 가장 먼저 등장한다")
    func nicknameFirst() {
        let car = FeedCar(
            id: "1",
            carModel: "아반떼",
            carColor: "검정",
            carYear: 2023,
            nickname: "내사랑"
        )
        let result = HashtagGenerator.generate(content: nil, car: car)
        #expect(result.first == "#내사랑")
    }

    @Test("차량 모델/색상/연식이 모두 추가된다")
    func carModelColorYear() {
        let car = FeedCar(
            id: "1",
            carModel: "쏘렌토",
            carColor: "흰색",
            carYear: 2024,
            nickname: nil
        )
        let result = HashtagGenerator.generate(content: nil, car: car)
        #expect(result.contains("#쏘렌토"))
        #expect(result.contains("#흰색"))
        #expect(result.contains("#2024년식"))
    }

    @Test("연식이 1980년 이하면 추가하지 않는다 (기본값 0 등 노이즈 방지)")
    func ignoresInvalidYear() {
        let car = FeedCar(
            id: "1",
            carModel: "아반떼",
            carColor: nil,
            carYear: 0,
            nickname: nil
        )
        let result = HashtagGenerator.generate(content: nil, car: car)
        #expect(!result.contains("#0년식"))
    }

    // MARK: - 명시적 해시태그 추출

    @Test("본문의 #셀프세차 같은 명시적 태그를 그대로 캡처한다")
    func extractsExplicitHashtag() {
        let result = HashtagGenerator.generate(content: "오늘 #신차피드 작성")
        #expect(result.contains("#신차피드"))
    }

    @Test("# 한 글자(=뒤에 텍스트 없음)는 무시한다")
    func ignoresLoneHashSymbol() {
        let result = HashtagGenerator.generate(content: "그냥 # 표시만")
        // 사전에 매칭될 키워드가 없으므로 결과는 비어 있어야 한다
        #expect(result.isEmpty)
    }

    // MARK: - 중복 제거 + maxCount

    @Test("같은 키워드가 여러 번 등장해도 한 번만 태깅된다")
    func deduplicates() {
        let result = HashtagGenerator.generate(content: "셀프세차 셀프세차 셀프세차")
        let count = result.filter { $0 == "#셀프세차" }.count
        #expect(count == 1)
    }

    @Test("maxCount 만큼만 반환한다")
    func respectsMaxCount() {
        let content = "셀프세차 손세차 자동세차 왁스 코팅 카샴푸 폼건 휠 유리"
        let result = HashtagGenerator.generate(content: content, maxCount: 3)
        #expect(result.count == 3)
    }

    // MARK: - 우선순위 (차량 → 세차방식 → 본문)

    @Test("차량 태그가 본문 태그보다 먼저 등장한다")
    func carTagsBeforeContent() {
        let car = FeedCar(
            id: "1",
            carModel: "아반떼",
            carColor: nil,
            carYear: nil,
            nickname: nil
        )
        let result = HashtagGenerator.generate(content: "셀프세차 했어요", car: car)
        let carIdx = result.firstIndex(of: "#아반떼")
        let methodIdx = result.firstIndex(of: "#셀프세차")
        if let c = carIdx, let m = methodIdx {
            #expect(c < m)
        } else {
            Issue.record("차량 또는 세차 방식 태그를 찾을 수 없음 - result: \(result)")
        }
    }
}
