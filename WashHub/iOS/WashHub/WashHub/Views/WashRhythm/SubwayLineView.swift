import SwiftUI

/// 지하철 노선도 시각화 — 세차 정거장 + 다음 추천 정거장
///
/// - 가로 스크롤. 마지막 = 다음 추천 정거장 (점선)
/// - 정거장 탭 → onStationTap callback
/// - 컴팩트 모드(true) — 마이페이지 카드용 작은 사이즈
/// - 풀 모드(false) — 풀스크린 상세 화면용
struct SubwayLineView: View {
    let stations: [WashRhythmStation]
    var compact: Bool = false
    var onStationTap: ((WashRhythmStation) -> Void)? = nil

    /// 정거장 사이 간격 (가로 픽셀)
    private var stationSpacing: CGFloat { compact ? 56 : 84 }
    /// 정거장 원 직경
    private var dotSize: CGFloat { compact ? 14 : 20 }
    /// 선 두께
    private var lineWidth: CGFloat { compact ? 2 : 3 }
    /// 라벨 폰트 사이즈
    private var labelSize: CGFloat { compact ? 10 : 12 }

    private let lineColor = Color.rhythmAccent

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    // 좌측 여백
                    Color.clear.frame(width: 16)

                    ForEach(Array(stations.enumerated()), id: \.element.id) { idx, station in
                        stationView(station: station, index: idx)
                            .id(station.id)
                    }

                    // 우측 여백
                    Color.clear.frame(width: 16)
                }
            }
            .onAppear {
                // 첫 진입 시 가장 우측(예정 정거장) 으로 자동 스크롤
                if let last = stations.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.4)) {
                            proxy.scrollTo(last.id, anchor: .trailing)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 정거장 + 연결선

    @ViewBuilder
    private func stationView(station: WashRhythmStation, index: Int) -> some View {
        HStack(spacing: 0) {
            // 이전 정거장으로 가는 연결선 (첫 정거장 제외)
            if index > 0 {
                connectingLine(toIndex: index)
                    .frame(width: stationSpacing - dotSize)
            }

            // 정거장 원 + 라벨
            Button(action: {
                onStationTap?(station)
            }) {
                VStack(spacing: 4) {
                    if !compact {
                        // 라벨 — D-N (예정 정거장만)
                        if station.kind == .nextRecommended {
                            nextRecommendedBadge
                                .frame(height: 16)
                        } else {
                            Color.clear.frame(height: 16)
                        }
                    }

                    stationDot(kind: station.kind)
                        .frame(width: dotSize, height: dotSize)

                    Text(station.shortDate)
                        .font(.system(size: labelSize, weight: station.kind == .nextRecommended ? .bold : .medium))
                        .foregroundColor(
                            station.kind == .nextRecommended
                                ? Color.rhythmAccent
                                : .theme.textSecondary
                        )
                        .fixedSize()
                }
            }
            .buttonStyle(.plain)
        }
    }

    /// 정거장 원 — past 면 채움, nextRecommended 면 외곽선만(점선)
    @ViewBuilder
    private func stationDot(kind: WashRhythmStation.Kind) -> some View {
        switch kind {
        case .past:
            Circle()
                .fill(lineColor)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: lineColor.opacity(0.3), radius: 3, y: 1)
        case .nextRecommended:
            Circle()
                .fill(Color.theme.surfaceLowest)
                .overlay(
                    Circle()
                        .stroke(
                            lineColor,
                            style: StrokeStyle(lineWidth: lineWidth, dash: [3, 3])
                        )
                )
        }
    }

    /// 정거장 사이 연결선 — 다음이 예정 정거장이면 점선
    @ViewBuilder
    private func connectingLine(toIndex: Int) -> some View {
        let nextIsRecommended = stations[toIndex].kind == .nextRecommended
        Rectangle()
            .fill(
                nextIsRecommended
                    ? Color.clear
                    : lineColor
            )
            .frame(height: lineWidth)
            .overlay(
                Group {
                    if nextIsRecommended {
                        // 점선
                        DashedLine()
                            .stroke(
                                lineColor.opacity(0.6),
                                style: StrokeStyle(lineWidth: lineWidth, dash: [4, 3])
                            )
                            .frame(height: lineWidth)
                    }
                }
            )
            .offset(y: compact ? 0 : 8)  // 라벨 영역 보정
    }

    /// "예정 D-N" 배지
    private var nextRecommendedBadge: some View {
        Text("예정")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(lineColor)
            )
    }
}

// MARK: - 점선 그리기 헬퍼
private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

#Preview {
    let now = Date()
    let cal = Calendar.current
    let stations: [WashRhythmStation] = [
        WashRhythmStation(id: "1", date: cal.date(byAdding: .day, value: -28, to: now)!, kind: .past, washLogId: "1", feedId: nil, memo: nil),
        WashRhythmStation(id: "2", date: cal.date(byAdding: .day, value: -20, to: now)!, kind: .past, washLogId: "2", feedId: nil, memo: nil),
        WashRhythmStation(id: "3", date: cal.date(byAdding: .day, value: -13, to: now)!, kind: .past, washLogId: "3", feedId: nil, memo: nil),
        WashRhythmStation(id: "4", date: cal.date(byAdding: .day, value: -5, to: now)!, kind: .past, washLogId: "4", feedId: nil, memo: nil),
        WashRhythmStation(id: "next", date: cal.date(byAdding: .day, value: 3, to: now)!, kind: .nextRecommended, washLogId: nil, feedId: nil, memo: nil)
    ]
    return VStack(spacing: 32) {
        Text("Compact").font(.caption)
        SubwayLineView(stations: stations, compact: true)
            .frame(height: 60)
            .background(Color.theme.surfaceLowest)

        Text("Full").font(.caption)
        SubwayLineView(stations: stations, compact: false)
            .frame(height: 100)
            .background(Color.theme.surfaceLowest)
    }
    .padding()
    .background(Color.theme.surface)
}
