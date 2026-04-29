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
