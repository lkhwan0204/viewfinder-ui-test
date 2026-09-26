import CoreLocation
import Observation

/// 위치와 나침반 방향. 권한은 사용자가 "가까운 곳"이 필요한 기능을 처음 누를 때 요청합니다.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    /// 위치 권한이 없을 때 쓰는 기준점 (서울시청)
    static let fallback = GeoPoint(37.5663, 126.9779)

    var authorization: CLAuthorizationStatus = .notDetermined
    var location: CLLocation?
    /// 진북 기준 기기 방향 (도)
    var heading: Double?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.headingFilter = 1
        authorization = manager.authorizationStatus
    }

    var isAuthorized: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }
    var isDenied: Bool { authorization == .denied || authorization == .restricted }
    var isUsingFallback: Bool { location == nil }
    var reference: GeoPoint { location.map { GeoPoint($0.coordinate) } ?? Self.fallback }
    var referenceName: String { isUsingFallback ? "서울 기준" : "내 위치" }
    var headingAvailable: Bool { CLLocationManager.headingAvailable() }

    func requestWhenInUse() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func startHeading() {
        guard CLLocationManager.headingAvailable() else { return }
        manager.startUpdatingHeading()
    }

    func stopHeading() {
        manager.stopUpdatingHeading()
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if isAuthorized { manager.startUpdatingLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let last = locations.last { location = last }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
