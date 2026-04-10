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
    @State private var showCarWashList = false

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
                                    NavigationLink(destination: EquipmentDetailView(equipment: equipment, onChanged: { await loadEquipments() })) {
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
                // 좌측: 세차장 목록 sheet 로 present (CarWashListView 가 자체 NavigationView 를 갖고 있어서
                // push 네비게이션은 NavigationView 중첩 경고가 발생함. sheet 로 모달 표시하는 편이 안전)
                // TODO-minam: Phase 2 에서 세차장 지도 탭 부활 시 이 버튼은 제거 예정
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showCarWashList = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                            Text("세차장")
                                .font(.appLabel)
                        }
                        .foregroundColor(.theme.secondary)
                    }
                }

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
            .sheet(isPresented: $showCarWashList) {
                CarWashListView()
                    .environmentObject(authManager)
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
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State var equipment: Equipment
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    var onChanged: () async -> Void

    /// 본인 소유 여부
    private var isOwner: Bool {
        guard let currentId = authManager.currentUser?.id,
              let ownerId = equipment.userId else { return false }
        return currentId == ownerId
    }

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
            EditEquipmentView(equipment: equipment) { updated in
                equipment = updated
                Task { await onChanged() }
            }
        }
        .alert("삭제하시겠습니까?", isPresented: $showDeleteConfirm) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                Task { await deleteEquipment() }
            }
        } message: {
            Text("삭제한 장비는 복구할 수 없습니다.")
        }
        .overlay {
            if isDeleting {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView().tint(.white)
            }
        }
    }

    private func deleteEquipment() async {
        isDeleting = true
        do {
            // Soft delete — status만 DELETED로 변경 (RLS로 본인만 허용)
            try await supabase
                .from("equipments")
                .update(["status": "DELETED"])
                .eq("id", value: equipment.id)
                .execute()
            await onChanged()
            dismiss()
        } catch {
            // TODO-minam: 사용자 알림 토스트 추가
            print("Equipment delete error: \(error)")
        }
        isDeleting = false
    }
}

// MARK: - 장비 수정
struct EditEquipmentView: View {
    @Environment(\.dismiss) var dismiss
    let equipment: Equipment
    var onUpdated: (Equipment) -> Void

    @State private var name: String
    @State private var brand: String
    @State private var category: String
    @State private var description: String
    @State private var price: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var imageChanged = false

    private let categories = ["샴푸", "왁스", "코팅제", "타월", "폼건", "기타"]

    init(equipment: Equipment, onUpdated: @escaping (Equipment) -> Void) {
        self.equipment = equipment
        self.onUpdated = onUpdated
        _name = State(initialValue: equipment.name)
        _brand = State(initialValue: equipment.brand ?? "")
        _category = State(initialValue: equipment.category)
        _description = State(initialValue: equipment.description ?? "")
        _price = State(initialValue: equipment.price.map { "\($0)" } ?? "")
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // 제품 사진 수정
                        editImageSection

                        TextField("제품명", text: $name).washHubTextField()
                        TextField("브랜드 (선택)", text: $brand).washHubTextField()
                        TextField("가격 (선택)", text: $price).washHubTextField()
                            .keyboardType(.numberPad)

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

                        Button(action: updateEquipment) {
                            if isLoading {
                                ProgressView().tint(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
                            } else {
                                Text("저장").primaryButtonStyle()
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
            .navigationTitle("장비 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }.foregroundColor(.theme.textSecondary)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker { image in
                    selectedImage = image
                    imageChanged = true
                }
            }
        }
    }

    // MARK: - 이미지 수정 섹션
    private var editImageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("제품 사진")
                .font(.appLabel)
                .foregroundColor(.theme.textSecondary)

            Button(action: { showImagePicker = true }) {
                if let image = selectedImage {
                    // 새로 선택한 이미지
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .topTrailing) {
                            Button(action: { selectedImage = nil; imageChanged = true }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                            }
                            .offset(x: -8, y: 8)
                        }
                } else if !imageChanged, let urlStr = equipment.imageUrl, !urlStr.isEmpty,
                          let url = URL(string: urlStr) {
                    // 기존 이미지
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            imagePlaceholder
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topTrailing) {
                        Button(action: { imageChanged = true }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        .offset(x: -8, y: 8)
                    }
                } else {
                    imagePlaceholder
                }
            }
        }
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.theme.surface)
            .frame(height: 140)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.theme.textDisabled)
                    Text("사진 변경")
                        .font(.appSmall)
                        .foregroundColor(.theme.textDisabled)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.theme.border, style: StrokeStyle(lineWidth: 1, dash: [6]))
            )
    }

    private func updateEquipment() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            // TODO-minam: 공통 유효성 처리로 전환
            errorMessage = "제품명을 입력해주세요."
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                // 1. 새 이미지 업로드 (변경된 경우)
                var imageUrlString: String? = imageChanged ? nil : equipment.imageUrl
                if imageChanged, let image = selectedImage,
                   let imageData = image.jpegDataUnder(maxDimension: 1024, maxBytes: 2 * 1024 * 1024) {
                    let path = "equipments/\(equipment.id).jpg"
                    // upsert: 기존 파일 덮어쓰기
                    try await supabase.storage
                        .from("equipments")
                        .upload(path: path, file: imageData, options: .init(contentType: "image/jpeg", upsert: true))
                    let publicUrl = try supabase.storage
                        .from("equipments")
                        .getPublicURL(path: path)
                    // 캐시 무효화를 위해 타임스탬프 파라미터 추가
                    imageUrlString = publicUrl.absoluteString + "?t=\(Int(Date().timeIntervalSince1970))"
                }

                // 2. 레코드 업데이트
                var data: [String: String] = [
                    "name": trimmedName,
                    "category": category,
                    "brand": brand,
                    "description": description
                ]
                if let p = Int(price) {
                    data["price"] = "\(p)"
                } else {
                    data["price"] = "0"
                }
                if let url = imageUrlString {
                    data["image_url"] = url
                } else if imageChanged {
                    // 이미지가 삭제된 경우 — 빈 문자열로 설정
                    data["image_url"] = ""
                }

                let persistUpdated: [Equipment] = try await supabase
                    .from("equipments")
                    .update(data)
                    .eq("id", value: equipment.id)
                    .select()
                    .execute()
                    .value

                if let updated = persistUpdated.first {
                    onUpdated(updated)
                }
                dismiss()
            } catch {
                errorMessage = "수정에 실패했습니다. 잠시 후 다시 시도해주세요."
                print("Equipment update error: \(error)")
            }
            isLoading = false
        }
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
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    var onComplete: () async -> Void

    private let categories = ["샴푸", "왁스", "코팅제", "타월", "폼건", "기타"]

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // 제품 사진
                        equipmentImagePicker

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
            .sheet(isPresented: $showImagePicker) {
                ImagePicker { image in
                    selectedImage = image
                }
            }
        }
    }

    // MARK: - 이미지 피커 UI
    private var equipmentImagePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("제품 사진 (선택)")
                .font(.appLabel)
                .foregroundColor(.theme.textSecondary)

            Button(action: { showImagePicker = true }) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .topTrailing) {
                            Button(action: { selectedImage = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                            }
                            .offset(x: -8, y: 8)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme.surface)
                        .frame(height: 140)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.theme.textDisabled)
                                Text("사진 추가")
                                    .font(.appSmall)
                                    .foregroundColor(.theme.textDisabled)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.theme.border, style: StrokeStyle(lineWidth: 1, dash: [6]))
                        )
                }
            }
        }
    }

    private func addEquipment() {
        isLoading = true
        Task {
            do {
                let session = try await supabase.auth.session
                let equipmentId = UUID().uuidString

                // 1. 이미지 업로드 (선택 시)
                var imageUrlString: String?
                if let image = selectedImage,
                   let imageData = image.jpegDataUnder(maxDimension: 1024, maxBytes: 2 * 1024 * 1024) {
                    let path = "equipments/\(equipmentId).jpg"
                    try await supabase.storage
                        .from("equipments")
                        .upload(path: path, file: imageData, options: .init(contentType: "image/jpeg"))
                    let publicUrl = try supabase.storage
                        .from("equipments")
                        .getPublicURL(path: path)
                    imageUrlString = publicUrl.absoluteString
                }

                // 2. 레코드 생성
                var data: [String: String] = [
                    "id": equipmentId,
                    "name": name,
                    "category": category,
                    "user_id": session.user.id.uuidString,
                    "status": "ACTIVE"
                ]
                if !brand.isEmpty { data["brand"] = brand }
                if !description.isEmpty { data["description"] = description }
                if let p = Int(price) { data["price"] = "\(p)" }
                if let url = imageUrlString { data["image_url"] = url }

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
