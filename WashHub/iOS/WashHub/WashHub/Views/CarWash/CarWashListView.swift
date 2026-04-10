import SwiftUI
import Supabase

// MARK: - 세차장 카테고리 / 편의시설 상수
enum CarWashCategory {
    static let all = "전체"
    static let values: [String] = ["셀프", "자동", "손세차", "스팀", "디테일링", "기타"]
    static var allCases: [String] { [all] + values }
}

enum CarWashFacility {
    static let values: [String] = ["진공청소기", "에어건", "세정제", "타월대여", "실내전용", "카드결제", "24시간", "주차"]
}

/// description 에서 편의시설 태그를 파싱한다.
/// 포맷: `[편의시설: A,B] 본문...`
func parseFacilities(from description: String?) -> (facilities: [String], body: String) {
    guard let desc = description else { return ([], "") }
    let pattern = "^\\[편의시설:\\s*([^\\]]*)\\]\\s*"
    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: desc, range: NSRange(desc.startIndex..., in: desc)),
       let tagRange = Range(match.range(at: 1), in: desc),
       let fullRange = Range(match.range, in: desc) {
        let facilities = desc[tagRange]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let body = String(desc[fullRange.upperBound...])
        return (facilities, body)
    }
    return ([], desc)
}

func encodeFacilities(_ facilities: [String], body: String) -> String {
    if facilities.isEmpty { return body }
    return "[편의시설: \(facilities.joined(separator: ","))] \(body)"
}

struct CarWashListView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var carWashes: [CarWash] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedCategory: String = CarWashCategory.all
    @State private var showAddCarWash = false
    @State private var showLoginAlert = false

    var filteredCarWashes: [CarWash] {
        var result = carWashes
        if selectedCategory != CarWashCategory.all {
            result = result.filter { ($0.washType ?? "") == selectedCategory }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.address.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 검색바
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.theme.textDisabled)
                        TextField("세차장 검색", text: $searchText)
                            .font(.appBody)
                            .foregroundColor(.theme.textPrimary)
                    }
                    .padding(12)
                    .background(Color.theme.surface)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    // 카테고리 필터
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CarWashCategory.allCases, id: \.self) { category in
                                Button(action: { selectedCategory = category }) {
                                    Text(category)
                                        .font(.appLabel)
                                        .foregroundColor(
                                            selectedCategory == category
                                            ? .white : .theme.textSecondary
                                        )
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedCategory == category
                                            ? Color.theme.secondary : Color.theme.surface
                                        )
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }

                    if isLoading {
                        Spacer()
                        ProgressView().tint(.theme.secondary)
                        Spacer()
                    } else if filteredCarWashes.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "mappin.circle")
                                .font(.system(size: 50))
                                .foregroundColor(.theme.textDisabled)
                            Text("등록된 세차장이 없습니다")
                                .font(.appCaption)
                                .foregroundColor(.theme.textDisabled)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredCarWashes) { carWash in
                                    NavigationLink(destination: CarWashDetailView(carWash: carWash, onChanged: { await loadCarWashes() })) {
                                        CarWashCard(carWash: carWash)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("세차장")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if authManager.isGuest { showLoginAlert = true }
                        else { showAddCarWash = true }
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.theme.secondary)
                    }
                }
            }
            .sheet(isPresented: $showAddCarWash) {
                AddCarWashView { await loadCarWashes() }
            }
            .alert("로그인이 필요해요", isPresented: $showLoginAlert) {
                Button("로그인하기") { authManager.exitGuestMode() }
                Button("계속 둘러보기", role: .cancel) {}
            } message: {
                Text("세차장 등록은 로그인 후 이용할 수 있습니다.")
            }
        }
        .task { await loadCarWashes() }
    }

    private func loadCarWashes() async {
        do {
            let persistCarWashes: [CarWash] = try await supabase
                .from("car_washes")
                .select()
                .eq("status", value: "ACTIVE")
                .order("created_at", ascending: false)
                .execute()
                .value
            carWashes = persistCarWashes
        } catch {
            print("Car washes load error: \(error)")
        }
        isLoading = false
    }
}

struct CarWashCard: View {
    let carWash: CarWash

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(carWash.name)
                        .font(.appBodyMedium)
                        .foregroundColor(.theme.textPrimary)

                    Text(carWash.address)
                        .font(.appSmall)
                        .foregroundColor(.theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if (carWash.rating ?? 0) > 0 {
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.theme.kakaoYellow)
                            Text(String(format: "%.1f", carWash.rating ?? 0))
                                .font(.appCaptionMedium)
                                .foregroundColor(.theme.textPrimary)
                        }
                        Text("리뷰 \(carWash.reviewCount ?? 0)")
                            .font(.appSmall)
                            .foregroundColor(.theme.textDisabled)
                    }
                }
            }

            if let phone = carWash.phone, !phone.isEmpty {
                Label(phone, systemImage: "phone")
                    .font(.appSmall)
                    .foregroundColor(.theme.textSecondary)
            }
        }
        .padding(12)
        .cardStyle()
    }
}

// MARK: - 세차장 상세
struct CarWashDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State var carWash: CarWash
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var showCallFailedAlert = false
    var onChanged: () async -> Void

    /// 전화 걸기 — 시뮬레이터/전화 불가 기기에서는 Alert 표시
    /// canOpenURL 은 Info.plist 의 LSApplicationQueriesSchemes 가 필요하므로 completion handler 로 결과를 확인한다
    private func callPhoneNumber(_ raw: String) {
        // 숫자와 '+' 만 남김 (공백, 하이픈, 괄호 모두 제거)
        let digits = raw.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty, let url = URL(string: "tel:\(digits)") else {
            showCallFailedAlert = true
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                // 메인 스레드에서 state 갱신
                DispatchQueue.main.async {
                    showCallFailedAlert = true
                }
            }
        }
    }

    private var isOwner: Bool {
        guard let currentId = authManager.currentUser?.id,
              let ownerId = carWash.userId else { return false }
        return currentId == ownerId
    }

    private var parsed: (facilities: [String], body: String) {
        parseFacilities(from: carWash.description)
    }

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 이미지
                    AsyncImage(url: URL(string: carWash.imageUrl ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Rectangle().fill(Color.theme.surface)
                                .overlay(
                                    Image(systemName: "mappin.circle")
                                        .font(.system(size: 50))
                                        .foregroundColor(.theme.textDisabled)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()

                    VStack(alignment: .leading, spacing: 12) {
                        // 이름 + 별점
                        HStack {
                            Text(carWash.name)
                                .font(.appHeadline1)
                                .foregroundColor(.theme.textPrimary)
                            Spacer()
                            if (carWash.rating ?? 0) > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.theme.kakaoYellow)
                                    Text(String(format: "%.1f", carWash.rating ?? 0))
                                        .foregroundColor(.theme.textPrimary)
                                }
                                .font(.appCaption)
                            }
                        }

                        // 정보
                        VStack(alignment: .leading, spacing: 8) {
                            Label(carWash.address, systemImage: "mappin.and.ellipse")
                                .font(.appCaption)
                                .foregroundColor(.theme.textSecondary)

                            if let phone = carWash.phone, !phone.isEmpty {
                                Button(action: { callPhoneNumber(phone) }) {
                                    Label(phone, systemImage: "phone.fill")
                                        .font(.appCaption)
                                        .foregroundColor(.theme.secondary)
                                }
                            }

                            if let hours = carWash.hours, !hours.isEmpty {
                                Label(hours, systemImage: "clock")
                                    .font(.appCaption)
                                    .foregroundColor(.theme.textSecondary)
                            }

                            if let washType = carWash.washType, !washType.isEmpty {
                                Label(washType, systemImage: "drop.fill")
                                    .font(.appCaption)
                                    .foregroundColor(.theme.tertiary)
                            }
                        }

                        // 편의시설 칩
                        if !parsed.facilities.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("편의시설")
                                    .font(.appLabel)
                                    .foregroundColor(.theme.textDisabled)
                                FlexibleChipsView(items: parsed.facilities)
                            }
                        }

                        Divider().background(Color.theme.border)

                        // 설명 (편의시설 태그 제거된 본문)
                        let bodyText = parsed.body.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !bodyText.isEmpty {
                            Text(bodyText)
                                .font(.appBody)
                                .foregroundColor(.theme.textSecondary)
                        } else {
                            Text("아직 상세 정보가 등록되지 않았습니다.")
                                .font(.appCaption)
                                .foregroundColor(.theme.textDisabled)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle(carWash.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showEdit = true }) {
                            Label("수정", systemImage: "pencil")
                        }
                        Button(role: .destructive, action: { showDeleteConfirm = true }) {
                            Label("삭제", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.theme.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditCarWashView(carWash: carWash) { updated in
                carWash = updated
                Task { await onChanged() }
            }
        }
        .alert("삭제하시겠습니까?", isPresented: $showDeleteConfirm) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                Task { await deleteCarWash() }
            }
        } message: {
            Text("삭제한 세차장은 복구할 수 없습니다.")
        }
        .alert("전화를 걸 수 없습니다", isPresented: $showCallFailedAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("이 기기에서는 전화를 걸 수 없습니다. 실기기에서 다시 시도해주세요.")
        }
        .overlay {
            if isDeleting {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView().tint(.white)
            }
        }
    }

    private func deleteCarWash() async {
        isDeleting = true
        do {
            try await supabase
                .from("car_washes")
                .update(["status": "DELETED"])
                .eq("id", value: carWash.id)
                .execute()
            await onChanged()
            dismiss()
        } catch {
            // TODO-minam: 에러 토스트 처리
            print("Car wash delete error: \(error)")
        }
        isDeleting = false
    }
}

// MARK: - 칩 나열 (편의시설)
struct FlexibleChipsView: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.appSmall)
                    .foregroundColor(.theme.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.theme.secondary.opacity(0.12))
                    .cornerRadius(12)
            }
        }
    }
}

// MARK: - 세차장 수정
struct EditCarWashView: View {
    @Environment(\.dismiss) var dismiss
    let carWash: CarWash
    var onUpdated: (CarWash) -> Void

    @State private var name: String
    @State private var address: String
    @State private var phone: String
    @State private var hours: String
    @State private var category: String
    @State private var description: String
    @State private var selectedFacilities: Set<String>
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(carWash: CarWash, onUpdated: @escaping (CarWash) -> Void) {
        self.carWash = carWash
        self.onUpdated = onUpdated
        _name = State(initialValue: carWash.name)
        _address = State(initialValue: carWash.address)
        _phone = State(initialValue: carWash.phone ?? "")
        _hours = State(initialValue: carWash.hours ?? "")
        _category = State(initialValue: carWash.washType ?? CarWashCategory.values.first!)

        let parsed = parseFacilities(from: carWash.description)
        _description = State(initialValue: parsed.body.trimmingCharacters(in: .whitespacesAndNewlines))
        _selectedFacilities = State(initialValue: Set(parsed.facilities))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        TextField("세차장 이름", text: $name).washHubTextField()
                        TextField("주소", text: $address).washHubTextField()
                        TextField("전화번호 (선택)", text: $phone).washHubTextField()
                            .keyboardType(.phonePad)
                        TextField("영업시간 (선택)", text: $hours).washHubTextField()

                        categoryChips
                        facilityChips

                        VStack(alignment: .leading, spacing: 8) {
                            Text("설명 (선택)")
                                .font(.appLabel)
                                .foregroundColor(.theme.textSecondary)
                            TextEditor(text: $description)
                                .font(.appBody)
                                .foregroundColor(.theme.textPrimary)
                                .frame(minHeight: 80)
                                .padding(12)
                                .background(Color.theme.surface)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.border, lineWidth: 1))
                                .onAppear { UITextView.appearance().backgroundColor = .clear }
                        }

                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.appCaption)
                                .foregroundColor(.theme.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: updateCarWash) {
                            if isLoading {
                                ProgressView().tint(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
                            } else {
                                Text("저장").primaryButtonStyle()
                            }
                        }
                        .disabled(name.isEmpty || address.isEmpty || isLoading)
                        .opacity((name.isEmpty || address.isEmpty) ? 0.4 : 1.0)
                    }
                    .padding(16)
                }
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .navigationTitle("세차장 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }.foregroundColor(.theme.textSecondary)
                }
            }
        }
    }

    private var categoryChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("카테고리")
                .font(.appLabel)
                .foregroundColor(.theme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CarWashCategory.values, id: \.self) { cat in
                        Button(action: { category = cat }) {
                            Text(cat)
                                .font(.appSmall)
                                .foregroundColor(category == cat ? .white : .theme.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(category == cat ? Color.theme.secondary : Color.theme.surface)
                                .cornerRadius(20)
                        }
                    }
                }
            }
        }
    }

    private var facilityChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("편의시설 (다중 선택)")
                .font(.appLabel)
                .foregroundColor(.theme.textSecondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(CarWashFacility.values, id: \.self) { facility in
                    let isSelected = selectedFacilities.contains(facility)
                    Button(action: {
                        if isSelected { selectedFacilities.remove(facility) }
                        else { selectedFacilities.insert(facility) }
                    }) {
                        HStack(spacing: 4) {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            Text(facility)
                        }
                        .font(.appSmall)
                        .foregroundColor(isSelected ? .white : .theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.theme.secondary : Color.theme.surface)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.border, lineWidth: isSelected ? 0 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func updateCarWash() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedAddress.isEmpty else {
            // TODO-minam: 공통 유효성 에러 처리
            errorMessage = "이름과 주소는 필수 입력입니다."
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let encodedDesc = encodeFacilities(
                    Array(selectedFacilities).sorted(),
                    body: description.trimmingCharacters(in: .whitespacesAndNewlines)
                )

                let data: [String: String] = [
                    "name": trimmedName,
                    "address": trimmedAddress,
                    "phone": phone,
                    "hours": hours,
                    "wash_type": category,
                    "description": encodedDesc
                ]

                let persistUpdated: [CarWash] = try await supabase
                    .from("car_washes")
                    .update(data)
                    .eq("id", value: carWash.id)
                    .select()
                    .execute()
                    .value

                if let updated = persistUpdated.first {
                    onUpdated(updated)
                }
                dismiss()
            } catch {
                errorMessage = "수정에 실패했습니다. 잠시 후 다시 시도해주세요."
                print("Car wash update error: \(error)")
            }
            isLoading = false
        }
    }
}

// MARK: - 세차장 등록
struct AddCarWashView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var hours = ""
    @State private var category: String = CarWashCategory.values.first!
    @State private var description = ""
    @State private var selectedFacilities: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    var onComplete: () async -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        TextField("세차장 이름", text: $name).washHubTextField()
                        TextField("주소", text: $address).washHubTextField()
                        TextField("전화번호 (선택)", text: $phone).washHubTextField()
                            .keyboardType(.phonePad)
                        TextField("영업시간 (선택) 예: 09:00~21:00", text: $hours).washHubTextField()

                        // 카테고리
                        VStack(alignment: .leading, spacing: 8) {
                            Text("카테고리")
                                .font(.appLabel)
                                .foregroundColor(.theme.textSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(CarWashCategory.values, id: \.self) { cat in
                                        Button(action: { category = cat }) {
                                            Text(cat)
                                                .font(.appSmall)
                                                .foregroundColor(category == cat ? .white : .theme.textSecondary)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(category == cat ? Color.theme.secondary : Color.theme.surface)
                                                .cornerRadius(20)
                                        }
                                    }
                                }
                            }
                        }

                        // 편의시설
                        VStack(alignment: .leading, spacing: 8) {
                            Text("편의시설 (다중 선택)")
                                .font(.appLabel)
                                .foregroundColor(.theme.textSecondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                                ForEach(CarWashFacility.values, id: \.self) { facility in
                                    let isSelected = selectedFacilities.contains(facility)
                                    Button(action: {
                                        if isSelected { selectedFacilities.remove(facility) }
                                        else { selectedFacilities.insert(facility) }
                                    }) {
                                        HStack(spacing: 4) {
                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                            Text(facility)
                                        }
                                        .font(.appSmall)
                                        .foregroundColor(isSelected ? .white : .theme.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color.theme.secondary : Color.theme.surface)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.border, lineWidth: isSelected ? 0 : 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("설명 (선택)")
                                .font(.appLabel)
                                .foregroundColor(.theme.textSecondary)
                            TextEditor(text: $description)
                                .font(.appBody)
                                .foregroundColor(.theme.textPrimary)
                                .frame(minHeight: 80)
                                .padding(12)
                                .background(Color.theme.surface)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.border, lineWidth: 1))
                                .onAppear { UITextView.appearance().backgroundColor = .clear }
                        }

                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.appCaption)
                                .foregroundColor(.theme.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: addCarWash) {
                            if isLoading {
                                ProgressView().tint(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
                            } else {
                                Text("등록").primaryButtonStyle()
                            }
                        }
                        .disabled(name.isEmpty || address.isEmpty || isLoading)
                        .opacity((name.isEmpty || address.isEmpty) ? 0.4 : 1.0)
                    }
                    .padding(16)
                }
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .navigationTitle("세차장 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }.foregroundColor(.theme.textSecondary)
                }
            }
        }
    }

    private func addCarWash() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedAddress.isEmpty else {
            // TODO-minam: 공통 유효성 에러 처리
            errorMessage = "이름과 주소는 필수 입력입니다."
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let session = try await supabase.auth.session
                let encodedDesc = encodeFacilities(
                    Array(selectedFacilities).sorted(),
                    body: description.trimmingCharacters(in: .whitespacesAndNewlines)
                )

                var data: [String: String] = [
                    "name": trimmedName,
                    "address": trimmedAddress,
                    "user_id": session.user.id.uuidString,
                    "status": "ACTIVE",
                    "wash_type": category
                ]
                if !phone.isEmpty { data["phone"] = phone }
                if !hours.isEmpty { data["hours"] = hours }
                if !encodedDesc.isEmpty { data["description"] = encodedDesc }

                try await supabase.from("car_washes").insert(data).execute()
                await onComplete()
                dismiss()
            } catch {
                errorMessage = "등록에 실패했습니다. 잠시 후 다시 시도해주세요."
                print("Add car wash error: \(error)")
            }
            isLoading = false
        }
    }
}
