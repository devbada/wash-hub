import SwiftUI

/// 차량별 세차 주기 설정 시트
/// 하이브리드 — 자동 / 프리셋 5개 / 직접 입력
struct IntervalSettingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rhythmService = WashRhythmService()

    let car: MyCar
    /// 저장 완료 콜백 (호출자가 차량 reload)
    var onSaved: (() -> Void)? = nil

    @State private var selection: WashIntervalOption
    @State private var customDaysText: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(car: MyCar, onSaved: (() -> Void)? = nil) {
        self.car = car
        self.onSaved = onSaved
        // 초기 선택 — preferred 가 있으면 그 값, 없으면 자동
        if let preferred = car.preferredWashIntervalDays {
            if WashIntervalOption.presetDays.contains(preferred) {
                _selection = State(initialValue: .preset(preferred))
            } else {
                _selection = State(initialValue: .custom(preferred))
                _customDaysText = State(initialValue: "\(preferred)")
            }
        } else {
            _selection = State(initialValue: .auto)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 차량 정보 헤더
                        carHeader

                        // 자동 옵션
                        autoOptionRow

                        Text("프리셋")
                            .font(.appCaption)
                            .foregroundColor(.theme.textSecondary)
                            .padding(.top, 8)

                        // 프리셋 옵션
                        VStack(spacing: 8) {
                            ForEach(WashIntervalOption.presetDays, id: \.self) { days in
                                presetRow(days: days)
                            }
                        }

                        Text("직접 입력")
                            .font(.appCaption)
                            .foregroundColor(.theme.textSecondary)
                            .padding(.top, 8)

                        customInputRow

                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.appCaption)
                                .foregroundColor(.theme.error)
                                .padding(.top, 8)
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("세차 주기 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.theme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: handleSave) {
                        if isSaving {
                            ProgressView().tint(Color.rhythmAccent)
                        } else {
                            Text("저장")
                                .font(.appBodyBold)
                                .foregroundColor(Color.rhythmAccent)
                        }
                    }
                    .disabled(isSaving || !isSelectionValid)
                }
            }
        }
    }

    // MARK: - 헤더

    private var carHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "car.fill")
                .font(.system(size: 20))
                .foregroundColor(Color.rhythmAccent)
                .frame(width: 44, height: 44)
                .background(Color.rhythmAccent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(car.nickname?.isEmpty == false ? car.nickname! : car.carModel)
                    .font(.appHeadline3)
                    .foregroundColor(.theme.textPrimary)
                if car.nickname?.isEmpty == false {
                    Text(car.carModel)
                        .font(.appCaption)
                        .foregroundColor(.theme.textSecondary)
                }
            }
            Spacer()
        }
    }

    // MARK: - 자동 옵션

    private var autoOptionRow: some View {
        Button(action: { selection = .auto }) {
            HStack {
                radioCircle(selected: isAutoSelected)
                VStack(alignment: .leading, spacing: 2) {
                    Text("자동")
                        .font(.appBodyBold)
                        .foregroundColor(.theme.textPrimary)
                    if let recommended = car.autoRecommendedIntervalDays {
                        Text("현재 추천: \(recommended)일")
                            .font(.appCaption)
                            .foregroundColor(.theme.textSecondary)
                    } else {
                        Text("기록이 더 쌓이면 추천이 시작됩니다 (기본 14일)")
                            .font(.appCaption)
                            .foregroundColor(.theme.textDisabled)
                    }
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isAutoSelected ? Color.rhythmAccent.opacity(0.08) : Color.theme.surfaceLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isAutoSelected ? Color.rhythmAccent : Color.theme.outline,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 프리셋 행

    private func presetRow(days: Int) -> some View {
        let selected = isPresetSelected(days)
        return Button(action: { selection = .preset(days) }) {
            HStack {
                radioCircle(selected: selected)
                Text("\(days)일")
                    .font(.appBody)
                    .foregroundColor(.theme.textPrimary)
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? Color.rhythmAccent.opacity(0.08) : Color.theme.surfaceLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        selected ? Color.rhythmAccent : Color.theme.outline,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 직접 입력

    private var customInputRow: some View {
        HStack {
            radioCircle(selected: isCustomSelected)
            TextField("일수 (1~60)", text: $customDaysText)
                .keyboardType(.numberPad)
                .font(.appBody)
                .foregroundColor(.theme.textPrimary)
                .onChange(of: customDaysText) { _, newValue in
                    // 숫자만 입력 + 1~60 클램프
                    let digits = newValue.filter(\.isNumber)
                    let limited = String(digits.prefix(2))
                    if limited != newValue {
                        customDaysText = limited
                    }
                    if let days = Int(limited), (1...60).contains(days) {
                        selection = .custom(days)
                    }
                }
            Text("일")
                .font(.appCaption)
                .foregroundColor(.theme.textSecondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCustomSelected ? Color.rhythmAccent.opacity(0.08) : Color.theme.surfaceLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isCustomSelected ? Color.rhythmAccent : Color.theme.outline,
                    lineWidth: 1
                )
        )
    }

    // MARK: - 라디오 버튼

    private func radioCircle(selected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(selected ? Color.rhythmAccent : Color.theme.outline, lineWidth: 2)
                .frame(width: 22, height: 22)
            if selected {
                Circle()
                    .fill(Color.rhythmAccent)
                    .frame(width: 12, height: 12)
            }
        }
    }

    // MARK: - 선택 상태 판별

    private var isAutoSelected: Bool {
        if case .auto = selection { return true }
        return false
    }
    private func isPresetSelected(_ days: Int) -> Bool {
        if case .preset(let d) = selection, d == days { return true }
        return false
    }
    private var isCustomSelected: Bool {
        if case .custom = selection { return true }
        return false
    }

    /// 저장 가능 여부 — 자동/프리셋은 항상 OK, 커스텀은 1~60 범위 체크
    private var isSelectionValid: Bool {
        switch selection {
        case .auto, .preset:
            return true
        case .custom(let days):
            return (1...60).contains(days)
        }
    }

    // MARK: - 저장

    private func handleSave() {
        Task {
            isSaving = true
            errorMessage = nil
            do {
                try await rhythmService.saveInterval(for: car, option: selection)
                onSaved?()
                dismiss()
            } catch {
                // TODO-minam: 저장 실패 시 사용자에게 친화적 메시지
                errorMessage = "저장에 실패했어요. 잠시 후 다시 시도해주세요."
                print("Interval save error: \(error)")
            }
            isSaving = false
        }
    }
}
