import Foundation
internal import CoreLocation
import Combine

/// Equatable 좌표 (onChange 호환)
struct EquatableCoordinate: Equatable {
    let latitude: Double
    let longitude: Double

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// 사용자 위치 관리 — CLLocationManager 래퍼
/// 위치 권한 요청, 현재 위치 갱신, 상태 추적
@MainActor
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Published State
    @Published var userLocation: EquatableCoordinate?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?

    // MARK: - Private
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Public API

    /// 위치 권한 요청
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// 현재 위치 1회 갱신
    func requestLocation() {
        locationError = nil
        manager.requestLocation()
    }

    /// 권한 거부 상태인지
    var isPermissionDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// 권한이 허용된 상태인지
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.userLocation = EquatableCoordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            self.locationError = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // TODO-minam: 에러 유형별 세분화
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = "위치 권한이 거부되었습니다. 설정에서 허용해주세요."
                case .locationUnknown:
                    self.locationError = "현재 위치를 확인할 수 없습니다. 잠시 후 다시 시도해주세요."
                default:
                    self.locationError = "위치를 가져올 수 없습니다."
                }
            } else {
                self.locationError = "위치를 가져올 수 없습니다."
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            // 권한 허용 시 자동으로 위치 요청
            if self.isAuthorized {
                self.requestLocation()
            }
        }
    }
}
