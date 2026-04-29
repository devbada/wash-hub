import Foundation

/// 세차 리듬 — 노선도 정거장 + 다음 세차일 추천에 사용되는 도메인 모델
///
/// 정거장 한 칸 = wash_logs 1건 또는 다음 추천 정거장(예정).

/// 노선도의 한 정거장
struct WashRhythmStation: Identifiable, Hashable {
    enum Kind: Hashable {
        case past               // 지난 세차 (wash_logs 한 건)
        case nextRecommended    // 다음 추천 정거장 (계산값, 미래)
    }

    let id: String                  // wash_log id 또는 "next-{carId}-{date}"
    let date: Date
    let kind: Kind
    /// 연결된 wash_log id — 탭하면 상세 진입 (kind == .past 만)
    let washLogId: String?
    /// 연결된 피드 id — 탭하면 피드 진입 (kind == .past 에서만 가능)
    let feedId: String?
    /// 메모 (있으면 정거장에 작은 표시)
    let memo: String?

    /// 표시용 짧은 날짜 ("4/22")
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: date)
    }
}

/// 차량별 세차 리듬 요약
struct WashRhythmSummary {
    /// 노선도 정거장 (오래된 순서)
    let stations: [WashRhythmStation]
    /// 평균 세차 간격 (일) — 데이터 부족 시 nil
    let averageIntervalDays: Int?
    /// 최근 세차 간격 (일) — 가장 최근 두 정거장 사이
    let recentIntervalDays: Int?
    /// 적용 주기 (effective) — 다음 세차일 계산에 사용된 값
    let effectiveIntervalDays: Int
    /// 자동 모드 여부 (사용자가 prefer 설정 안 함)
    let isAutoMode: Bool
    /// 마지막 세차일
    let lastWashDate: Date?
    /// 다음 세차 추천일
    let nextWashDate: Date?
    /// 다음 세차일까지 남은 일수 (음수면 이미 지남)
    let daysUntilNextWash: Int?
    /// 올해 누적 세차 횟수
    let washCountThisYear: Int

    /// 데이터 부족 여부 (정거장 < 2개)
    var hasInsufficientData: Bool {
        stations.filter { $0.kind == .past }.count < 2
    }
}

/// 세차 주기 옵션 — 설정 시트에서 사용
enum WashIntervalOption: Hashable {
    case auto
    case preset(Int)
    case custom(Int)

    var displayLabel: String {
        switch self {
        case .auto:           return "자동"
        case .preset(let d):  return "\(d)일"
        case .custom(let d):  return "\(d)일 (직접 입력)"
        }
    }

    /// DB 저장값 — auto 면 nil, 그 외엔 일수
    var storedValue: Int? {
        switch self {
        case .auto:           return nil
        case .preset(let d):  return d
        case .custom(let d):  return d
        }
    }

    /// 프리셋 일수 목록 (UI 노출 순서)
    static let presetDays: [Int] = [7, 10, 14, 21, 30]
}

// MARK: - 다음 세차 날씨 (P3-013)

/// 다음 세차 추천일에 표시할 날씨 정보
///
/// D-Day 거리에 따라 데이터 소스가 달라진다.
/// - D-1~7: 7일 예보(`mode: "forecast"`) 의 해당 일자 데이터 — 정확
/// - D-8~14: 7일 예보가 커버되면 그 데이터, 없으면 장기로 fallback
/// - D-15~30: 장기(`mode: "longrange"`) — 작년 동일주 평균
/// - D-30+: 표시 불가
struct NextWashWeather {
    enum Source {
        case shortTerm        // 7일 예보 기반
        case longRange        // 작년 동일주 평균 기반
        case unavailable      // 데이터 없음 (D-30+ 또는 작년 데이터 미수집)
    }

    let source: Source
    let date: Date
    let daysUntil: Int

    /// 강수 확률 (단기 예보 기준) — 장기에서는 nil
    let rainProbability: Int?
    /// 평균/예측 기온 (℃)
    let temperature: Double?
    /// 세차지수 0~100
    let score: Int?
    /// 친화적 메시지 — "맑음 · 92점" 또는 "작년 5월 첫째주 평균 비 2일"
    let message: String

    /// 신뢰도 별점 (1~5)
    /// - 단기예보(가까울수록): 5
    /// - 7일 예보 끝(D-7): 4
    /// - 장기(작년): 2~3
    /// - unavailable: 0
    let reliability: Int

    /// 비 예보 또는 작년 비 많았던 주 — UI 에서 비 아이콘 강조
    let isRainExpected: Bool
}

/// `weather-proxy` 의 `mode: "longrange"` 응답
struct LongRangeWeatherResponse: Codable {
    let targetDate: String
    let hasData: Bool
    let avgRainMm: Double?
    let avgTemp: Double?
    let avgHumidity: Double?
    let rainDays: Int
    let avgScore: Int?
    let sampleDays: Int
    /// 1~3
    let reliability: Int
    let message: String
}
