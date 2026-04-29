//
//  TimedCacheTests.swift
//  WashHubTests
//
//  TimedCache<Key, Value> 단위 테스트
//  - TTL 내 hit, TTL 만료 후 miss
//  - invalidate / invalidateAll
//  - @MainActor 고립 — Swift Testing 도 @MainActor 어노테이션으로 호출
//

import Testing
import Foundation
@testable import WashHub

@MainActor
struct TimedCacheTests {

    // MARK: - 기본 set / value

    @Test("set 직후 같은 key 조회는 저장한 값을 그대로 반환한다")
    func setThenGetReturnsValue() {
        let cache = TimedCache<String, Int>(ttl: 60)
        cache.set(42, for: "foo")
        #expect(cache.value(for: "foo") == 42)
    }

    @Test("저장하지 않은 key 는 nil 을 반환한다")
    func missingKeyReturnsNil() {
        let cache = TimedCache<String, Int>(ttl: 60)
        #expect(cache.value(for: "absent") == nil)
    }

    @Test("set 으로 같은 key 에 새 값을 쓰면 덮어쓴다")
    func setOverwritesExistingValue() {
        let cache = TimedCache<String, String>(ttl: 60)
        cache.set("first", for: "k")
        cache.set("second", for: "k")
        #expect(cache.value(for: "k") == "second")
    }

    // MARK: - TTL 만료

    @Test("TTL 이 0초면 즉시 만료되어 nil 을 반환한다")
    func zeroTTLExpiresImmediately() async throws {
        let cache = TimedCache<String, Int>(ttl: 0)
        cache.set(1, for: "k")
        // 약간의 시간 진행 — Date().timeIntervalSince > 0 보장
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        #expect(cache.value(for: "k") == nil)
    }

    @Test("TTL 이 충분히 길면 hit 한다")
    func longTTLHits() {
        let cache = TimedCache<String, Int>(ttl: 60)
        cache.set(1, for: "k")
        #expect(cache.value(for: "k") == 1)
    }

    // MARK: - invalidate

    @Test("invalidate(for:) 는 해당 키만 제거한다")
    func invalidateRemovesSpecificKey() {
        let cache = TimedCache<String, Int>(ttl: 60)
        cache.set(1, for: "a")
        cache.set(2, for: "b")
        cache.invalidate(for: "a")
        #expect(cache.value(for: "a") == nil)
        #expect(cache.value(for: "b") == 2)
    }

    @Test("invalidateAll() 은 모든 키를 제거한다")
    func invalidateAllClearsCache() {
        let cache = TimedCache<String, Int>(ttl: 60)
        cache.set(1, for: "a")
        cache.set(2, for: "b")
        cache.set(3, for: "c")
        cache.invalidateAll()
        #expect(cache.value(for: "a") == nil)
        #expect(cache.value(for: "b") == nil)
        #expect(cache.value(for: "c") == nil)
    }

    @Test("존재하지 않는 키를 invalidate 해도 에러가 발생하지 않는다")
    func invalidateMissingKeyIsNoop() {
        let cache = TimedCache<String, Int>(ttl: 60)
        cache.invalidate(for: "missing") // 예외 없이 통과
        #expect(cache.value(for: "missing") == nil)
    }

    // MARK: - 다양한 Value 타입

    @Test("Codable struct 도 정상적으로 캐싱된다")
    func cachesStructValues() {
        struct Sample: Equatable {
            let id: Int
            let name: String
        }
        let cache = TimedCache<String, Sample>(ttl: 60)
        let sample = Sample(id: 1, name: "wash")
        cache.set(sample, for: "k")
        #expect(cache.value(for: "k") == sample)
    }
}
