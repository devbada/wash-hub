import SwiftUI
import MapKit
import Supabase

/// Apple Maps POI 검색 결과를 지도 어노테이션으로 표시하기 위한 모델
struct CarWashPOI: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let phone: String?
    let coordinate: CLLocationCoordinate2D
    let mapItem: MKMapItem
    /// DB에 이미 즐겨찾기 등록된 세차장이면 해당 ID
    var registeredId: String?

    var isRegistered: Bool { registeredId != nil }
}

// MARK: - 세차장 지도 뷰 (Apple Maps POI 검색 + 즐겨찾기)
struct CarWashMapView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var locationManager = LocationManager()
    @State private var pois: [CarWashPOI] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var selectedPOI: CarWashPOI?
    @State private var hasSearched = false
    @State private var toastMessage: String?
    @State private var navigateToDetail: CarWash?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    /// DB에 등록된 세차장 (좌표 기반 매칭용)
    @State private var registeredCarWashes: [CarWash] = []

    /// POI 검색 결과 + DB 등록 세차장(POI에 없는 것)을 합친 전체 마커
    private var allAnnotations: [CarWashPOI] {
        var result = pois

        // DB에 등록된 세차장 중 POI 검색에 안 잡힌 것들을 추가
        let poiRegisteredIds = Set(pois.compactMap { $0.registeredId })
        for cw in registeredCarWashes {
            guard let lat = cw.latitude, let lng = cw.longitude else { continue }
            guard !poiRegisteredIds.contains(cw.id) else { continue }

            // 현재 지도 영역 안에 있는 것만 표시
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            guard isCoordinate(coord, inRegion: region) else { continue }

            result.append(CarWashPOI(
                name: cw.name,
                address: cw.address,
                phone: cw.phone,
                coordinate: coord,
                mapItem: MKMapItem(placemark: MKPlacemark(coordinate: coord)),
                registeredId: cw.id
            ))
        }
        return result
    }

    /// 좌표가 지도 영역 안에 있는지 확인
    private func isCoordinate(_ coord: CLLocationCoordinate2D, inRegion region: MKCoordinateRegion) -> Bool {
        let latRange = (region.center.latitude - region.span.latitudeDelta)...(region.center.latitude + region.span.latitudeDelta)
        let lngRange = (region.center.longitude - region.span.longitudeDelta)...(region.center.longitude + region.span.longitudeDelta)
        return latRange.contains(coord.latitude) && lngRange.contains(coord.longitude)
    }

    var body: some View {
        ZStack {
            // 지도
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: allAnnotations) { poi in
                MapAnnotation(coordinate: poi.coordinate) {
                    poiMarker(poi)
                }
            }
            .ignoresSafeArea(edges: .top)

            // 오버레이
            VStack {
                // 상단: 이 지역에서 검색 버튼
                searchButton
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer()

                // 하단: 선택된 세차장 카드 또는 결과 요약
                if let selected = selectedPOI {
                    selectedPOICard(selected)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if hasSearched {
                    resultSummary
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }

            // 토스트 메시지
            if let toast = toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.appLabel)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.theme.surfaceLow.cornerRadius(20))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // 로딩
            if isLoading {
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.3)
                    .padding(20)
                    .background(Color.theme.surfaceLow.cornerRadius(12))
            }

            // 위치 권한 안내
            if locationManager.isPermissionDenied {
                permissionDeniedOverlay
            }
        }
        .onAppear {
            locationManager.requestPermission()
            Task { await loadRegisteredCarWashes() }
        }
        .onChange(of: locationManager.userLocation) { _, newLocation in
            if let loc = newLocation {
                region = MKCoordinateRegion(
                    center: loc.clCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                Task { await searchCarWashPOIs() }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedPOI?.id)
        .animation(.easeInOut(duration: 0.3), value: toastMessage)
        // 상세 화면 네비게이션
        .navigationDestination(isPresented: Binding(
            get: { navigateToDetail != nil },
            set: { if !$0 { navigateToDetail = nil } }
        )) {
            if let carWash = navigateToDetail {
                CarWashDetailView(carWash: carWash, onChanged: {
                    await loadRegisteredCarWashes()
                })
            }
        }
    }

    // MARK: - 검색 버튼
    private var searchButton: some View {
        HStack(spacing: 12) {
            Button(action: {
                Task { await searchCarWashPOIs() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .bold))
                    Text("이 지역에서 세차장 검색")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThickMaterial)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }

            Spacer()

            // 내 위치로 이동
            Button(action: {
                locationManager.requestLocation()
            }) {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.theme.secondary)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
        }
    }

    // MARK: - 결과 요약
    private var resultSummary: some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(.theme.secondary)

            let registeredCount = pois.filter { $0.isRegistered }.count
            if pois.isEmpty {
                Text("주변에 세차장이 없습니다")
                    .font(.appLabel)
                    .foregroundColor(.theme.textPrimary)
            } else {
                Text("세차장 \(pois.count)곳 발견")
                    .font(.appLabel)
                    .foregroundColor(.theme.textPrimary)
                if registeredCount > 0 {
                    Text("(\(registeredCount)곳 등록됨)")
                        .font(.appSmall)
                        .foregroundColor(.theme.tertiary)
                }
            }

            Spacer()
            Text("지도를 이동 후 재검색")
                .font(.appSmall)
                .foregroundColor(.theme.textSecondary)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: - 지도 마커
    private func poiMarker(_ poi: CarWashPOI) -> some View {
        Button(action: {
            withAnimation { selectedPOI = poi }
        }) {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(markerColor(for: poi))
                        .frame(width: 36, height: 36)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                    // 등록된 세차장: 별 아이콘 / 미등록: 물방울 아이콘
                    Image(systemName: poi.isRegistered ? "star.fill" : "drop.fill")
                        .font(.system(size: poi.isRegistered ? 14 : 16))
                        .foregroundColor(markerIconColor(for: poi))
                }

                // 이름 라벨 (선택된 경우만)
                if selectedPOI?.id == poi.id {
                    Text(poi.name)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.theme.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                }
            }
        }
    }

    private func markerColor(for poi: CarWashPOI) -> Color {
        if selectedPOI?.id == poi.id {
            return poi.isRegistered ? Color.theme.tertiary : Color.theme.secondary
        }
        return poi.isRegistered ? Color.theme.tertiary.opacity(0.85) : Color.theme.surfaceLow
    }

    private func markerIconColor(for poi: CarWashPOI) -> Color {
        if selectedPOI?.id == poi.id {
            return .white
        }
        return poi.isRegistered ? .white : .theme.secondary
    }

    // MARK: - 선택된 세차장 카드
    private func selectedPOICard(_ poi: CarWashPOI) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 상단: 이름, 주소, 즐겨찾기/닫기
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(poi.name)
                            .font(.appBodyMedium)
                            .foregroundColor(.theme.textPrimary)

                        if poi.isRegistered {
                            Text("등록됨")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.theme.tertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.theme.tertiary.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }

                    Text(poi.address)
                        .font(.appSmall)
                        .foregroundColor(.theme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                // 즐겨찾기 버튼
                Button(action: {
                    if poi.isRegistered {
                        // 이미 등록됨 → 상세 페이지로 이동
                        if let carWash = registeredCarWashes.first(where: { $0.id == poi.registeredId }) {
                            navigateToDetail = carWash
                        }
                    } else {
                        Task { await bookmarkCarWash(poi) }
                    }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: poi.isRegistered ? "star.fill" : "star")
                            .font(.system(size: 22))
                            .foregroundColor(poi.isRegistered ? .theme.tertiary : .theme.textSecondary)

                        Text(poi.isRegistered ? "상세보기" : "즐겨찾기")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(poi.isRegistered ? .theme.tertiary : .theme.textSecondary)
                    }
                }
                .disabled(isSaving)

                // 닫기
                Button(action: {
                    withAnimation { selectedPOI = nil }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.theme.textDisabled)
                }
            }

            // 전화 + 길찾기
            HStack(spacing: 8) {
                if let phone = poi.phone, !phone.isEmpty {
                    Button(action: { callPhone(phone) }) {
                        Label(phone, systemImage: "phone.fill")
                            .font(.appSmall)
                            .foregroundColor(.theme.secondary)
                    }
                }
                Spacer()
                Button(action: { openInMaps(poi) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond")
                            .font(.system(size: 12))
                        Text("길찾기")
                            .font(.appLabel)
                    }
                    .foregroundColor(.theme.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.theme.secondary.opacity(0.15))
                    .cornerRadius(16)
                }

                Button(action: { openInAppleMaps(poi) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 12))
                        Text("지도앱")
                            .font(.appLabel)
                    }
                    .foregroundColor(.theme.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.theme.tertiary.opacity(0.15))
                    .cornerRadius(16)
                }
            }
        }
        .padding(16)
        .background(.ultraThickMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }

    // MARK: - 권한 거부 오버레이
    private var permissionDeniedOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 40))
                .foregroundColor(.theme.textDisabled)

            Text("위치 권한이 필요합니다")
                .font(.appBodyMedium)
                .foregroundColor(.theme.textPrimary)

            Text("주변 세차장을 찾으려면 위치 접근을 허용해주세요.")
                .font(.appCaption)
                .foregroundColor(.theme.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("설정으로 이동")
                    .font(.appLabel)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.theme.secondary)
                    .cornerRadius(20)
            }
        }
        .padding(32)
        .background(.ultraThickMaterial)
        .cornerRadius(20)
        .padding(40)
    }

    // MARK: - Apple Maps POI 검색
    private func searchCarWashPOIs() async {
        isLoading = true
        selectedPOI = nil

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "세차장"
        request.region = region

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            var results = response.mapItems.compactMap { item -> CarWashPOI? in
                guard let location = item.placemark.location else { return nil }

                let address = [
                    item.placemark.administrativeArea,
                    item.placemark.locality,
                    item.placemark.thoroughfare,
                    item.placemark.subThoroughfare
                ]
                .compactMap { $0 }
                .joined(separator: " ")

                return CarWashPOI(
                    name: item.name ?? "세차장",
                    address: address.isEmpty ? (item.placemark.title ?? "주소 없음") : address,
                    phone: item.phoneNumber,
                    coordinate: location.coordinate,
                    mapItem: item
                )
            }

            // DB에 등록된 세차장과 매칭 (이름 + 근접 좌표)
            results = results.map { poi in
                var mutable = poi
                mutable.registeredId = findRegisteredId(for: poi)
                return mutable
            }

            pois = results
            hasSearched = true
        } catch {
            // TODO-minam: 검색 실패 시 사용자 안내 개선
            print("MKLocalSearch error: \(error)")
            pois = []
            hasSearched = true
        }

        isLoading = false
    }

    // MARK: - DB 등록 세차장 로드
    private func loadRegisteredCarWashes() async {
        do {
            let persistCarWashes: [CarWash] = try await supabase
                .from("car_washes")
                .select()
                .eq("status", value: "ACTIVE")
                .execute()
                .value

            registeredCarWashes = persistCarWashes
        } catch {
            print("Load registered car washes error: \(error)")
        }
    }

    // MARK: - POI와 DB 세차장 매칭 (이름 유사 + 좌표 근접 100m 이내)
    private func findRegisteredId(for poi: CarWashPOI) -> String? {
        let threshold = 0.001 // 약 100m
        return registeredCarWashes.first { cw in
            guard let lat = cw.latitude, let lng = cw.longitude else { return false }
            let latDiff = abs(lat - poi.coordinate.latitude)
            let lngDiff = abs(lng - poi.coordinate.longitude)
            // 좌표 근접 매칭 (100m 이내) 또는 이름 + 좌표 느슨한 매칭 (500m)
            if latDiff < threshold && lngDiff < threshold {
                return true
            }
            let looseThreshold = 0.005 // 약 500m
            if latDiff < looseThreshold && lngDiff < looseThreshold
                && cw.name.contains(poi.name.prefix(4)) {
                return true
            }
            return false
        }?.id
    }

    // MARK: - 즐겨찾기 (DB 저장)
    private func bookmarkCarWash(_ poi: CarWashPOI) async {
        guard authManager.isAuthenticated,
              let userId = authManager.currentUser?.id else {
            showToast("로그인이 필요합니다")
            return
        }

        isSaving = true

        do {
            var data: [String: String] = [
                "name": poi.name,
                "address": poi.address,
                "latitude": String(poi.coordinate.latitude),
                "longitude": String(poi.coordinate.longitude),
                "user_id": userId,
                "status": "ACTIVE"
            ]
            if let phone = poi.phone, !phone.isEmpty {
                data["phone"] = phone
            }

            let persistSaved: [CarWash] = try await supabase
                .from("car_washes")
                .insert(data)
                .select()
                .execute()
                .value

            if let saved = persistSaved.first {
                // 등록 목록에 추가
                registeredCarWashes.append(saved)

                // 현재 POI 목록에서 해당 항목 업데이트
                if let idx = pois.firstIndex(where: { $0.id == poi.id }) {
                    pois[idx].registeredId = saved.id
                    selectedPOI = pois[idx]
                }

                showToast("'\(poi.name)' 즐겨찾기 완료! 목록에서 확인하세요.")
            }
        } catch {
            // TODO-minam: 중복 등록 방지 에러 처리
            print("Bookmark car wash error: \(error)")
            showToast("등록에 실패했습니다. 잠시 후 다시 시도해주세요.")
        }

        isSaving = false
    }

    // MARK: - 토스트 메시지
    private func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation { toastMessage = nil }
        }
    }

    // MARK: - Apple Maps 길찾기
    private func openInMaps(_ poi: CarWashPOI) {
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: poi.coordinate))
        destination.name = poi.name
        destination.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    // MARK: - Apple Maps 앱에서 열기
    private func openInAppleMaps(_ poi: CarWashPOI) {
        poi.mapItem.openInMaps(launchOptions: nil)
    }

    // MARK: - 전화 걸기
    private func callPhone(_ phone: String) {
        let cleaned = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        if let url = URL(string: "tel://\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }
}
