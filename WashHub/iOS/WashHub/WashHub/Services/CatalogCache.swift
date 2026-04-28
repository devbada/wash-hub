import Foundation

/// 거의 변하지 않는 카탈로그 데이터(케미컬 리스트, 세차장 리스트)의 캐시
///
/// - TTL 5분 (마스터 데이터 성격이라 길게 가져감)
/// - 사용자가 새로 추가/수정/삭제 시 명시적 invalidation 필요
/// - View 의 .task 에서 첫 로드는 캐시 우선, pull-to-refresh 등 강제 새로고침은 forceRefresh=true
@MainActor
enum CatalogCache {
    private static let ttl: TimeInterval = 5 * 60

    /// 케미컬/장비 리스트
    static let equipmentList = TimedCache<String, [Equipment]>(ttl: ttl)

    /// 세차장 리스트
    static let carWashList = TimedCache<String, [CarWash]>(ttl: ttl)

    /// 단일 키 — 카탈로그는 사용자/필터별 분리 안 하고 전역 캐시
    static let key = "all"

    /// 카탈로그 변경 시 호출 (Equipment/CarWash 추가/수정/삭제)
    static func invalidateEquipmentList() {
        equipmentList.invalidateAll()
    }

    static func invalidateCarWashList() {
        carWashList.invalidateAll()
    }
}
