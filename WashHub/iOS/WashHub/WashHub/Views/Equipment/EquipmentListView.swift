import SwiftUI
import Supabase

struct EquipmentListView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var equipments: [Equipment] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedCategory = "전체"
    @State private var showAddEquipment = false
    @State private var showLoginAlert = false

    private let categories = ["전체", "샴푸", "왁스", "코팅제", "타월", "폼건", "기타"]

    var filteredEquipments: [Equipment] {
        var result = equipments
        if selectedCategory != "전체" {
            result = result.filter { $0.category == selectedCategory }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
                        TextField("케미컬/장비 검색", text: $searchText)
                            .font(.appBody)
                            .foregroundColor(.theme.textPrimary)
                    }
                    .padding(12)
                    .background(Color.theme.surface)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // 카테고리 필터
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { category in
                                Button(action: { selectedCategory = category }) {
                                    Text(category)
                                        .font(.appLabel)
                                        .foregroundColor(
                                            selectedCategory == category
                                            ? .black : .theme.textSecondary
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
                        .padding(.vertical, 12)
                    }

                    // 장비 리스트
                    if isLoading {
                        Spacer()
                        ProgressView().tint(.theme.secondary)
                        Spacer()
                    } else if filteredEquipments.isEmpty {
                        Spacer()
                        Text("장비가 없습니다")
                            .font(.appCaption)
                            .foregroundColor(.theme.textDisabled)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredEquipments) { equipment in
                                    NavigationLink(destination: EquipmentDetailView(equipment: equipment)) {
                                        EquipmentCard(equipment: equipment)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("케미컬")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if authManager.isGuest { showLoginAlert = true }
                        else { showAddEquipment = true }
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.theme.secondary)
                    }
                }
            }
            .sheet(isPresented: $showAddEquipment) {
                AddEquipmentView { await loadEquipments() }
            }
            .alert("로그인이 필요해요", isPresented: $showLoginAlert) {
                Button("로그인하기") { authManager.exitGuestMode() }
                Button("계속 둘러보기", role: .cancel) {}
            } message: {
                Text("장비 등록은 로그인 후 이용할 수 있습니다.")
            }
        }
        .task { await loadEquipments() }
    }

    private func loadEquipments() async {
        do {
            let persistEquipments: [Equipment] = try await supabase
                .from("equipments")
                .select()
                .eq("status", value: "ACTIVE")
                .order("created_at", ascending: false)
                .execute()
                .value
            equipments = persistEquipments
        } catch {
            print("Equipments load error: \(error)")
        }
        isLoading = false
    }
}

struct EquipmentCard: View {
    let equipment: Equipment

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: equipment.imageUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.theme.surface)
                        .overlay(
                            Image(systemName: "drop.circle")
                                .foregroundColor(.theme.textDisabled)
                        )
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(equipment.name)
                    .font(.appBodyMedium)
                    .foregroundColor(.theme.textPrimary)

                HStack(spacing: 4) {
                    Text(equipment.category)
                        .font(.appSmall)
                        .foregroundColor(.theme.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.theme.secondary.opacity(0.15))
                        .cornerRadius(4)

                    if (equipment.rating ?? 0) > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.theme.kakaoYellow)
                            Text(String(format: "%.1f", equipment.rating ?? 0))
                                .font(.appSmall)
                                .foregroundColor(.theme.textSecondary)
                        }
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.theme.textDisabled)
                .font(.system(size: 12))
        }
        .padding(12)
        .cardStyle()
    }
}

// MARK: - 장비 상세
struct EquipmentDetailView: View {
    let equipment: Equipment

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 이미지
                    AsyncImage(url: URL(string: equipment.imageUrl ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Rectangle().fill(Color.theme.surface)
                                .overlay(
                                    Image(systemName: "drop.circle")
                                        .font(.system(size: 50))
                                        .foregroundColor(.theme.textDisabled)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .clipped()

                    VStack(alignment: .leading, spacing: 12) {
                        // 카테고리 + 별점
                        HStack {
                            Text(equipment.category)
                                .font(.appSmall)
                                .foregroundColor(.theme.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.theme.secondary.opacity(0.15))
                                .cornerRadius(6)

                            if (equipment.rating ?? 0) > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.theme.kakaoYellow)
                                    Text(String(format: "%.1f", equipment.rating ?? 0))
                                        .foregroundColor(.theme.textPrimary)
                                    Text("(\(equipment.reviewCount ?? 0))")
                                        .foregroundColor(.theme.textDisabled)
                                }
                                .font(.appSmall)
                            }
                        }

                        // 이름
                        Text(equipment.name)
                            .font(.appHeadline1)
                            .foregroundColor(.theme.textPrimary)

                        // 브랜드 + 가격
                        HStack(spacing: 16) {
                            if let brand = equipment.brand, !brand.isEmpty {
                                Label(brand, systemImage: "building.2")
                                    .font(.appCaption)
                                    .foregroundColor(.theme.textSecondary)
                            }
                            if let price = equipment.price, price > 0 {
                                Label("\(price.formatted())원", systemImage: "wonsign.circle")
                                    .font(.appCaption)
                                    .foregroundColor(.theme.tertiary)
                            }
                        }

                        Divider().background(Color.theme.border)

                        // 설명
                        if let desc = equipment.description, !desc.isEmpty {
                            Text(desc)
                                .font(.appBody)
                                .foregroundColor(.theme.textSecondary)
                        } else {
                            Text("아직 설명이 등록되지 않았습니다.")
                                .font(.appCaption)
                                .foregroundColor(.theme.textDisabled)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle(equipment.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 장비 등록
struct AddEquipmentView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var brand = ""
    @State private var category = "샴푸"
    @State private var description = ""
    @State private var price = ""
    @State private var isLoading = false
    var onComplete: () async -> Void

    private let categories = ["샴푸", "왁스", "코팅제", "타월", "폼건", "기타"]

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        TextField("제품명", text: $name).washHubTextField()
                        TextField("브랜드 (선택)", text: $brand).washHubTextField()
                        TextField("가격 (선택)", text: $price).washHubTextField()
                            .keyboardType(.numberPad)

                        // 카테고리 선택
                        VStack(alignment: .leading, spacing: 8) {
                            Text("카테고리")
                                .font(.appLabel)
                                .foregroundColor(.theme.textSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(categories, id: \.self) { cat in
                                        Button(action: { category = cat }) {
                                            Text(cat)
                                                .font(.appSmall)
                                                .foregroundColor(category == cat ? .black : .theme.textSecondary)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(category == cat ? Color.theme.secondary : Color.theme.surface)
                                                .cornerRadius(20)
                                        }
                                    }
                                }
                            }
                        }

                        // 설명
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

                        Button(action: addEquipment) {
                            if isLoading {
                                ProgressView().tint(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
                            } else {
                                Text("등록").primaryButtonStyle()
                            }
                        }
                        .disabled(name.isEmpty || isLoading)
                        .opacity(name.isEmpty ? 0.4 : 1.0)
                    }
                    .padding(16)
                }
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .navigationTitle("장비 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }.foregroundColor(.theme.textSecondary)
                }
            }
        }
    }

    private func addEquipment() {
        isLoading = true
        Task {
            do {
                let session = try await supabase.auth.session
                var data: [String: String] = [
                    "name": name,
                    "category": category,
                    "user_id": session.user.id.uuidString,
                    "status": "ACTIVE"
                ]
                if !brand.isEmpty { data["brand"] = brand }
                if !description.isEmpty { data["description"] = description }
                if let p = Int(price) { data["price"] = "\(p)" }

                try await supabase.from("equipments").insert(data).execute()
                await onComplete()
                dismiss()
            } catch {
                print("Add equipment error: \(error)")
            }
            isLoading = false
        }
    }
}
