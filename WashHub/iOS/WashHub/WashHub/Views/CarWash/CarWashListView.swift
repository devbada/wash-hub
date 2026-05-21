import SwiftUI
import Supabase
import CoreLocation
import MapKit

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
    @Environment(\.dismiss) private var dismiss
    @State private var carWashes: [CarWash] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedCategory: String = CarWashCategory.all
    @State private var showAddCarWash = false
    @State private var showLoginAlert = false
    @State private var showMapView = false

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
        NavigationStack {
            ZStack {
                Color.theme.surface.ignoresSafeArea()

                if showMapView {
                    CarWashMapView()
                } else {

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
                        VStack(spacing: 16) {
                            Image(systemName: "star.circle")
                                .font(.system(size: 56))
                                .foregroundColor(.theme.secondary.opacity(0.6))

                            VStack(spacing: 6) {
                                Text("아직 추가한 세차장이 없어요")
                                    .font(.appBodyBold)
                                    .foregroundColor(.theme.textPrimary)
                                Text("지도에서 자주 가는 세차장을\n즐겨찾기에 추가해 보세요.")
                                    .font(.appCaption)
                                    .foregroundColor(.theme.textSecondary)
                                    .multilineTextAlignment(.center)
                            }

                            Button(action: { showMapView = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "map.fill")
                                    Text("지도에서 찾기")
                                }
                                .font(.appLabel)
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.theme.secondary))
                            }
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, 32)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredCarWashes) { carWash in
                                    NavigationLink(destination: CarWashDetailView(carWash: carWash, onChanged: { await loadCarWashes(forceRefresh: true) })) {
                                        CarWashCard(carWash: carWash)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                    }
                }

                } // if-else showMapView 닫기
            }
            .navigationTitle("세차장")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.theme.textPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showMapView.toggle() }) {
                        Image(systemName: showMapView ? "list.bullet" : "map")
                            .foregroundColor(.theme.secondary)
                    }
                }
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
                AddCarWashView { await loadCarWashes(forceRefresh: true) }
            }
            .alert("로그인이 필요해요", isPresented: $showLoginAlert) {
                Button("로그인하기") { authManager.exitGuestMode() }
                Button("계속 둘러보기", role: .cancel) {}
            } message: {
                Text("세차장 등록은 로그인 후 이용할 수 있습니다.")
            }
        }
        .task { await loadCarWashes() }
        .onChange(of: showMapView) { _, isMap in
            if !isMap {
                // 지도 → 목록 전환 시 즐겨찾기된 세차장 즉시 반영 (캐시 무시)
                Task { await loadCarWashes(forceRefresh: true) }
            }
        }
    }

    /// - Parameter forceRefresh: true면 캐시 무시 (사용자 추가/수정/삭제 후 호출)
    private func loadCarWashes(forceRefresh: Bool = false) async {
        // 캐시 hit → 즉시 반환
        if !forceRefresh, let cached = CatalogCache.carWashList.value(for: CatalogCache.key) {
            carWashes = cached
            return
        }
        do {
            let persistCarWashes: [CarWash] = try await supabase
                .from("car_washes")
                .select()
                .eq("status", value: "ACTIVE")
                .order("created_at", ascending: false)
                .execute()
                .value
            carWashes = persistCarWashes
            CatalogCache.carWashList.set(persistCarWashes, for: CatalogCache.key)
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
    @StateObject private var reviewService = CarWashReviewService()
    @State var carWash: CarWash
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var showCallFailedAlert = false
    @State private var showReviewSheet = false
    @State private var showLoginAlert = false
    @State private var showDeleteReviewConfirm = false
    @State private var reviewToDelete: CarWashReview?
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
                    // 미니 지도 또는 이미지
                    if let lat = carWash.latitude, let lng = carWash.longitude {
                        CarWashMiniMapView(
                            name: carWash.name,
                            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipped()
                    } else if let imageUrl = carWash.imageUrl, !imageUrl.isEmpty {
                        AsyncImage(url: URL(string: imageUrl)) { phase in
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
                    } else {
                        Rectangle().fill(Color.theme.surface)
                            .overlay(
                                Image(systemName: "mappin.circle")
                                    .font(.system(size: 50))
                                    .foregroundColor(.theme.textDisabled)
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                    }

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

                        Divider().background(Color.theme.border)

                        // MARK: - 리뷰 섹션
                        carWashReviewSection
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
        .task {
            await reviewService.loadReviews(carWashId: carWash.id)
            if !authManager.isGuest {
                await reviewService.checkMyReview(carWashId: carWash.id)
            }
        }
        .sheet(isPresented: $showEdit) {
            EditCarWashView(carWash: carWash) { updated in
                carWash = updated
                Task { await onChanged() }
            }
        }
        .sheet(isPresented: $showReviewSheet) {
            WriteCarWashReviewSheet(
                carWashId: carWash.id,
                existingReview: reviewService.myExistingReview,
                reviewService: reviewService
            ) {
                Task { await refreshCarWash() }
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
        .alert("리뷰를 삭제하시겠습니까?", isPresented: $showDeleteReviewConfirm) {
            Button("취소", role: .cancel) { reviewToDelete = nil }
            Button("삭제", role: .destructive) {
                if let review = reviewToDelete {
                    Task {
                        try? await reviewService.deleteReview(reviewId: review.id, carWashId: carWash.id)
                        await refreshCarWash()
                        reviewToDelete = nil
                    }
                }
            }
        } message: {
            Text("삭제한 리뷰는 복구할 수 없습니다.")
        }
        .alert("전화를 걸 수 없습니다", isPresented: $showCallFailedAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("이 기기에서는 전화를 걸 수 없습니다. 실기기에서 다시 시도해주세요.")
        }
        .alert("로그인이 필요해요", isPresented: $showLoginAlert) {
            Button("로그인하기") { authManager.exitGuestMode() }
            Button("계속 둘러보기", role: .cancel) {}
        } message: {
            Text("리뷰 작성은 로그인 후 이용할 수 있습니다.")
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
            // 카탈로그 캐시 무효화
            CatalogCache.invalidateCarWashList()
            await onChanged()
            dismiss()
        } catch {
            // TODO-minam: 에러 토스트 처리
            print("Car wash delete error: \(error)")
        }
        isDeleting = false
    }

    // MARK: - 리뷰 섹션
    private var carWashReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                Text("리뷰")
                    .font(.appHeadline3)
                    .foregroundColor(.theme.textPrimary)

                if !reviewService.reviews.isEmpty {
                    Text("\(reviewService.reviews.count)")
                        .font(.appSmall)
                        .foregroundColor(.theme.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.theme.secondary.opacity(0.15))
                        .cornerRadius(8)
                }

                Spacer()

                // 리뷰 작성 버튼
                Button(action: {
                    if authManager.isGuest {
                        showLoginAlert = true
                    } else {
                        showReviewSheet = true
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: reviewService.myExistingReview != nil ? "pencil" : "plus")
                        Text(reviewService.myExistingReview != nil ? "내 리뷰 수정" : "리뷰 작성")
                    }
                    .font(.appLabel)
                    .foregroundColor(.theme.secondary)
                }
            }

            // 리뷰 목록
            if reviewService.isLoading {
                HStack {
                    Spacer()
                    ProgressView().tint(.theme.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if reviewService.reviews.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 28))
                        .foregroundColor(.theme.textDisabled)
                    Text("아직 리뷰가 없습니다")
                        .font(.appCaption)
                        .foregroundColor(.theme.textDisabled)
                    Text("첫 번째 리뷰를 남겨보세요!")
                        .font(.appSmall)
                        .foregroundColor(.theme.textDisabled)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(reviewService.reviews) { review in
                    CarWashReviewRow(
                        review: review,
                        isMyReview: review.userId == authManager.currentUser?.id,
                        onEdit: { showReviewSheet = true },
                        onDelete: {
                            reviewToDelete = review
                            showDeleteReviewConfirm = true
                        }
                    )
                }
            }
        }
    }

    // MARK: - 세차장 데이터 갱신 (리뷰 후 별점/리뷰수 반영)
    private func refreshCarWash() async {
        do {
            let persistCarWashes: [CarWash] = try await supabase
                .from("car_washes")
                .select()
                .eq("id", value: carWash.id)
                .limit(1)
                .execute()
                .value
            if let updated = persistCarWashes.first {
                carWash = updated
            }
        } catch {
            print("Car wash refresh error: \(error)")
        }
        await onChanged()
    }
}

// MARK: - 세차장 리뷰 행
struct CarWashReviewRow: View {
    let review: CarWashReview
    let isMyReview: Bool
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 프로필
                AsyncImage(url: URL(string: review.profiles?.avatarUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Circle().fill(Color.theme.surface)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.theme.textDisabled)
                                    .font(.system(size: 12))
                            )
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(review.profiles?.nickname ?? "사용자")
                        .font(.appLabel)
                        .foregroundColor(.theme.textPrimary)

                    Text(formatDate(review.createdAt))
                        .font(.appSmall)
                        .foregroundColor(.theme.textDisabled)
                }

                Spacer()

                // 별점
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= review.rating ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundColor(star <= review.rating ? .theme.kakaoYellow : .theme.textDisabled)
                    }
                }

                // 내 리뷰 메뉴
                if isMyReview {
                    Menu {
                        Button(action: onEdit) {
                            Label("수정", systemImage: "pencil")
                        }
                        Button(role: .destructive, action: onDelete) {
                            Label("삭제", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundColor(.theme.textDisabled)
                            .padding(4)
                    }
                }
            }

            // 리뷰 텍스트
            if let text = review.reviewText, !text.isEmpty {
                Text(text)
                    .font(.appBody)
                    .foregroundColor(.theme.textSecondary)
                    .lineLimit(nil)
            }
        }
        .padding(12)
        .cardStyle()
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else {
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            guard let d = fallback.date(from: dateString) else { return dateString }
            return RelativeDateTimeFormatter().localizedString(for: d, relativeTo: Date())
        }
        let relative = RelativeDateTimeFormatter()
        relative.locale = Locale(identifier: "ko_KR")
        return relative.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 세차장 리뷰 작성/수정 시트
struct WriteCarWashReviewSheet: View {
    @Environment(\.dismiss) var dismiss
    let carWashId: String
    let existingReview: CarWashReview?
    @ObservedObject var reviewService: CarWashReviewService

    @State private var rating: Int
    @State private var reviewText: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var onComplete: () -> Void

    var isEditing: Bool { existingReview != nil }

    init(carWashId: String, existingReview: CarWashReview?, reviewService: CarWashReviewService, onComplete: @escaping () -> Void) {
        self.carWashId = carWashId
        self.existingReview = existingReview
        self.reviewService = reviewService
        self.onComplete = onComplete
        _rating = State(initialValue: existingReview?.rating ?? 0)
        _reviewText = State(initialValue: existingReview?.reviewText ?? "")
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 별점 선택
                        VStack(spacing: 8) {
                            Text("별점을 선택해주세요")
                                .font(.appBodyMedium)
                                .foregroundColor(.theme.textPrimary)

                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { star in
                                    Button(action: { rating = star }) {
                                        Image(systemName: star <= rating ? "star.fill" : "star")
                                            .font(.system(size: 36))
                                            .foregroundColor(star <= rating ? .theme.kakaoYellow : .theme.textDisabled)
                                    }
                                }
                            }
                            .padding(.vertical, 8)

                            if rating > 0 {
                                Text(ratingLabel(rating))
                                    .font(.appCaption)
                                    .foregroundColor(.theme.secondary)
                            }
                        }

                        // 리뷰 텍스트
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("리뷰 (선택)")
                                    .font(.appLabel)
                                    .foregroundColor(.theme.textSecondary)
                                Spacer()
                                Text("\(reviewText.count)/500")
                                    .font(.appSmall)
                                    .foregroundColor(reviewText.count > 500 ? .theme.error : .theme.textDisabled)
                            }

                            TextEditor(text: $reviewText)
                                .font(.appBody)
                                .foregroundColor(.theme.textPrimary)
                                .frame(minHeight: 120)
                                .padding(12)
                                .background(Color.theme.surface)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.theme.border, lineWidth: 1)
                                )
                                .onAppear { UITextView.appearance().backgroundColor = .clear }
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.appCaption)
                                .foregroundColor(.theme.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // 제출 버튼
                        Button(action: submitReview) {
                            if isSubmitting {
                                ProgressView().tint(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            } else {
                                Text(isEditing ? "수정하기" : "등록하기")
                                    .primaryButtonStyle()
                            }
                        }
                        .disabled(rating == 0 || reviewText.count > 500 || isSubmitting)
                        .opacity(rating == 0 ? 0.4 : 1.0)
                    }
                    .padding(16)
                }
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .navigationTitle(isEditing ? "리뷰 수정" : "리뷰 작성")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.theme.textSecondary)
                }
            }
        }
    }

    private func ratingLabel(_ value: Int) -> String {
        switch value {
        case 1: return "별로예요"
        case 2: return "그저 그래요"
        case 3: return "보통이에요"
        case 4: return "좋아요"
        case 5: return "최고예요!"
        default: return ""
        }
    }

    private func submitReview() {
        guard rating >= 1 && rating <= 5 else {
            errorMessage = "별점을 선택해주세요."
            return
        }
        guard reviewText.count <= 500 else {
            errorMessage = "리뷰는 500자 이내로 작성해주세요."
            return
        }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let text = reviewText.isEmpty ? nil : reviewText

                if let existing = existingReview {
                    try await reviewService.updateReview(
                        reviewId: existing.id,
                        carWashId: carWashId,
                        rating: rating,
                        reviewText: text
                    )
                } else {
                    try await reviewService.addReview(
                        carWashId: carWashId,
                        rating: rating,
                        reviewText: text
                    )
                }

                onComplete()
                dismiss()
            } catch {
                // TODO-minam: 중복 리뷰 에러 분기 처리 (unique constraint)
                if "\(error)".contains("duplicate") || "\(error)".contains("unique") {
                    errorMessage = "이미 리뷰를 작성하셨습니다."
                } else {
                    errorMessage = "저장에 실패했습니다. 잠시 후 다시 시도해주세요."
                }
                print("Car wash review submit error: \(error)")
            }
            isSubmitting = false
        }
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

                var data: [String: String] = [
                    "name": trimmedName,
                    "address": trimmedAddress,
                    "phone": phone,
                    "hours": hours,
                    "wash_type": category,
                    "description": encodedDesc
                ]

                // 주소가 변경된 경우 좌표 재변환
                if trimmedAddress != carWash.address {
                    if let coordinate = await geocodeAddress(trimmedAddress) {
                        data["latitude"] = String(coordinate.latitude)
                        data["longitude"] = String(coordinate.longitude)
                    }
                }

                let persistUpdated: [CarWash] = try await supabase
                    .from("car_washes")
                    .update(data)
                    .eq("id", value: carWash.id)
                    .select()
                    .execute()
                    .value

                // 카탈로그 캐시 무효화
                CatalogCache.invalidateCarWashList()

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

                // 주소 → 좌표 변환 (지오코딩)
                if let coordinate = await geocodeAddress(trimmedAddress) {
                    data["latitude"] = String(coordinate.latitude)
                    data["longitude"] = String(coordinate.longitude)
                }

                try await supabase.from("car_washes").insert(data).execute()
                // 카탈로그 캐시 무효화
                CatalogCache.invalidateCarWashList()
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

// MARK: - 주소 → 좌표 변환 (CLGeocoder)
/// 주소 문자열을 위·경도 좌표로 변환한다.
/// Apple CLGeocoder를 사용하며, 실패 시 nil을 반환한다.
private func geocodeAddress(_ address: String) async -> CLLocationCoordinate2D? {
    let geocoder = CLGeocoder()
    do {
        let placemarks = try await geocoder.geocodeAddressString(address)
        if let location = placemarks.first?.location {
            return location.coordinate
        }
    } catch {
        // TODO-minam: 지오코딩 실패 로깅 / 사용자 안내 개선
        print("Geocoding failed for '\(address)': \(error)")
    }
    return nil
}

// MARK: - 세차장 미니 지도 (상세 화면 상단)
struct CarWashMiniMapView: View {
    let name: String
    let coordinate: CLLocationCoordinate2D

    @State private var region: MKCoordinateRegion

    init(name: String, coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.coordinate = coordinate
        _region = State(initialValue: MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(coordinateRegion: $region, annotationItems: [
                MapPin(id: "pin", coordinate: coordinate)
            ]) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    VStack(spacing: 2) {
                        ZStack {
                            Circle()
                                .fill(Color.theme.secondary)
                                .frame(width: 32, height: 32)
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                            Image(systemName: "drop.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        Text(name)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.theme.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial)
                            .cornerRadius(4)
                    }
                }
            }
            .allowsHitTesting(false)

            // 길찾기 버튼
            Button(action: {
                let destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                destination.name = name
                destination.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond")
                        .font(.system(size: 12))
                    Text("길찾기")
                        .font(.appLabel)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.theme.secondary)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
            .padding(12)
        }
    }
}

/// 미니 지도 어노테이션용 아이템
private struct MapPin: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
}
