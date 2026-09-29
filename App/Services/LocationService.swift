import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((Result<GeoPoint, Error>) -> Void)?
    private var timeout: Task<Void, Never>?
    @Published private(set) var busy = false
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    func request(completion: @escaping (Result<GeoPoint, Error>) -> Void) {
        guard !busy else { return }
        self.completion = completion
        busy = true
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(25))
            guard !Task.isCancelled else { return }
            self?.finish(.failure(LocationError.timeout))
        }
        checkAuthorization()
    }
    private func checkAuthorization() {
        guard busy else { return }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: finish(.failure(LocationError.denied))
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { checkAuthorization() }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        let point = GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, recordedAt: location.timestamp, source: "現在地")
        guard point.valid else { return }
        finish(.success(point))
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { finish(.failure(error)) }
    private func finish(_ result: Result<GeoPoint, Error>) {
        timeout?.cancel(); timeout = nil
        manager.stopUpdatingLocation()
        busy = false
        let callback = completion; completion = nil
        callback?(result)
    }
}
enum LocationError: LocalizedError {
    case denied, timeout
    var errorDescription: String? {
        switch self {
        case .denied: return "位置情報を利用できません。設定アプリで位置情報の許可を確認してください。"
        case .timeout: return "現在地を取得できませんでした。場所を変えて再試行してください。"
        }
    }
}
