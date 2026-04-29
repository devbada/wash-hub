//
//  DynamicIconServiceTests.swift
//  WashHubTests
//
//  DynamicIconService.iconName(daysSinceWash:) 단위 테스트
//  - 단계별 경계값 (0/2/3/5/6/10/11/20/21) 모두 검증
//  - 음수/거대값 케이스
//  - DB/UIKit 의존 없는 순수 매핑 함수만 테스트
//

import Testing
@testable import WashHub

@MainActor
struct DynamicIconServiceTests {

    private var service: DynamicIconService { DynamicIconService.shared }

    // MARK: - Just Washed (Primary, 0~2일)

    @Test("0일 차는 Primary 아이콘 (nil)")
    func zeroDaysIsPrimary() {
        #expect(service.iconName(daysSinceWash: 0) == nil)
    }

    @Test("2일 차는 여전히 Primary 아이콘 (nil)")
    func twoDaysIsPrimary() {
        #expect(service.iconName(daysSinceWash: 2) == nil)
    }

    // MARK: - Clean (3~5일)

    @Test("3일 차는 AppIconClean")
    func threeDaysIsClean() {
        #expect(service.iconName(daysSinceWash: 3) == "AppIconClean")
    }

    @Test("5일 차는 AppIconClean (Clean 단계 마지막)")
    func fiveDaysIsClean() {
        #expect(service.iconName(daysSinceWash: 5) == "AppIconClean")
    }

    // MARK: - Normal (6~10일)

    @Test("6일 차는 AppIconNormal")
    func sixDaysIsNormal() {
        #expect(service.iconName(daysSinceWash: 6) == "AppIconNormal")
    }

    @Test("10일 차는 AppIconNormal (Normal 마지막)")
    func tenDaysIsNormal() {
        #expect(service.iconName(daysSinceWash: 10) == "AppIconNormal")
    }

    // MARK: - Dirty (11~20일)

    @Test("11일 차는 AppIconDirty")
    func elevenDaysIsDirty() {
        #expect(service.iconName(daysSinceWash: 11) == "AppIconDirty")
    }

    @Test("20일 차는 AppIconDirty (Dirty 마지막)")
    func twentyDaysIsDirty() {
        #expect(service.iconName(daysSinceWash: 20) == "AppIconDirty")
    }

    // MARK: - Wash Me (21일+)

    @Test("21일 차는 AppIconWashMe")
    func twentyOneDaysIsWashMe() {
        #expect(service.iconName(daysSinceWash: 21) == "AppIconWashMe")
    }

    @Test("매우 큰 일수도 AppIconWashMe (기록 없음 → 999 케이스 포함)")
    func veryLargeDaysIsWashMe() {
        #expect(service.iconName(daysSinceWash: 999) == "AppIconWashMe")
    }

    // MARK: - 경계 누락 방지

    @Test("음수 일수는 default(WashMe)로 처리된다 — 정의되지 않은 입력 안전망")
    func negativeDaysFallsToDefault() {
        // 음수는 0...2 / 3...5 / 6...10 / 11...20 어느 범위에도 안 들어가서 default 분기
        #expect(service.iconName(daysSinceWash: -1) == "AppIconWashMe")
    }
}
