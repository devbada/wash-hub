import SwiftUI
import Supabase

struct CarWashListView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var carWashes: [CarWash] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var showAddCarWash = false
    @State private var showLoginAlert = false

    var filteredCarWashes: [CarWash] {
        if searchText.isEmpty { return carWashes }
        return carWashes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.address.localizedCaseInsensitiveContains(searchText)
        }
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
                                    NavigationLink(destination: CarWashDetailView(carWash: carWash)) {
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
    let carWash: CarWash

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
                                Button(action: {
                                    if let url = URL(string: "tel://\(phone.replacingOccurrences(of: "-", with: ""))") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
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

                        Divider().background(Color.theme.border)

                        // 설명
                        if let desc = carWash.description, !desc.isEmpty {
                            Text(desc)
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
    }
}

// MARK: - 세차장 등록
struct AddCarWashView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var hours = ""
    @State private var washType = ""
    @State private var description = ""
    @State private var isLoading = false
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
                        TextField("세차 유형 (선택) 예: 셀프, 자동, 손세차", text: $washType).washHubTextField()

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
        isLoading = true
        Task {
            do {
                let session = try await supabase.auth.session
                var data: [String: String] = [
                    "name": name,
                    "address": address,
                    "user_id": session.user.id.uuidString,
                    "status": "ACTIVE"
                ]
                if !phone.isEmpty { data["phone"] = phone }
                if !hours.isEmpty { data["hours"] = hours }
                if !washType.isEmpty { data["wash_type"] = washType }
                if !description.isEmpty { data["description"] = description }

                try await supabase.from("car_washes").insert(data).execute()
                await onComplete()
                dismiss()
            } catch {
                print("Add car wash error: \(error)")
            }
            isLoading = false
        }
    }
}
