/*
See LICENSE folder for this sample's licensing information.

Abstract:
Manages WiFi signal strength sampling during room scanning.
*/

import Foundation
import CoreLocation
import NetworkExtension
import SystemConfiguration.CaptiveNetwork

/// Represents a single WiFi signal measurement at a specific location
struct WiFiSample: Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let ssid: String?
    let bssid: String?
    let rssi: Int  // Signal strength in dBm (-30 excellent to -90 poor)
    let position: Position

    struct Position: Codable, Sendable {
        let x: Float
        let y: Float
        let z: Float
    }

    /// Signal quality category
    var signalQuality: SignalQuality {
        switch rssi {
        case -50...0: return .excellent
        case -60..<(-50): return .good
        case -70..<(-60): return .fair
        default: return .poor
        }
    }

    enum SignalQuality: String, Codable {
        case excellent, good, fair, poor

        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "yellow"
            case .fair: return "orange"
            case .poor: return "red"
            }
        }
    }
}

/// Manages WiFi signal sampling during room scanning
@MainActor
final class WiFiSignalManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isEnabled: Bool = false
    @Published var isAuthorized: Bool = false
    @Published var currentRSSI: Int?
    @Published var currentSSID: String?
    @Published var sampleCount: Int = 0

    // MARK: - Private Properties

    private var samples: [WiFiSample] = []
    private var locationManager: CLLocationManager?
    private var samplingTimer: Timer?
    private var currentPosition: SIMD3<Float> = .zero
    private var pendingEnable: Bool = false  // True when waiting for permission to enable

    private let samplingInterval: TimeInterval = 2.0  // Sample every 2 seconds

    // MARK: - Initialization

    override init() {
        super.init()
        setupLocationManager()
    }

    // MARK: - Public API

    /// Request location permission (required for WiFi info)
    func requestPermission() {
        pendingEnable = true  // Mark that we should enable after permission granted
        locationManager?.requestWhenInUseAuthorization()
    }

    /// Start sampling WiFi signal
    func startSampling() {
        guard isEnabled && isAuthorized else { return }

        samples.removeAll()
        sampleCount = 0

        // Start periodic sampling
        samplingTimer = Timer.scheduledTimer(withTimeInterval: samplingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.takeSample()
            }
        }

        // Take first sample immediately
        takeSample()
    }

    /// Stop sampling
    func stopSampling() {
        samplingTimer?.invalidate()
        samplingTimer = nil
    }

    /// Update the current device position (call from RoomCaptureSession)
    func updatePosition(_ position: SIMD3<Float>) {
        currentPosition = position
    }

    /// Get all collected samples
    var collectedSamples: [WiFiSample] {
        samples
    }

    /// Clear all samples
    func clearSamples() {
        samples.removeAll()
        sampleCount = 0
        currentRSSI = nil
        currentSSID = nil
    }

    /// Check if WiFi tracking is available on this device
    var isAvailable: Bool {
        // WiFi info requires location permission on iOS
        return CLLocationManager.locationServicesEnabled()
    }

    // MARK: - Private Methods

    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self

        // Check current authorization status
        updateAuthorizationStatus()
    }

    private func updateAuthorizationStatus() {
        guard let manager = locationManager else { return }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }

    private func takeSample() {
        // Get current WiFi info
        fetchCurrentWiFiInfo { [weak self] ssid, bssid, rssi in
            guard let self = self else { return }

            Task { @MainActor in
                self.currentSSID = ssid
                self.currentRSSI = rssi

                // Only save sample if we have valid data
                if let rssi = rssi {
                    let sample = WiFiSample(
                        id: UUID(),
                        timestamp: Date(),
                        ssid: ssid,
                        bssid: bssid,
                        rssi: rssi,
                        position: WiFiSample.Position(
                            x: self.currentPosition.x,
                            y: self.currentPosition.y,
                            z: self.currentPosition.z
                        )
                    )
                    self.samples.append(sample)
                    self.sampleCount = self.samples.count
                }
            }
        }
    }

    private func fetchCurrentWiFiInfo(completion: @escaping (String?, String?, Int?) -> Void) {
        // Method 1: Use NEHotspotNetwork (iOS 14+)
        if #available(iOS 14.0, *) {
            NEHotspotNetwork.fetchCurrent { [weak self] network in
                guard let self = self else { return }
                if let network = network {
                    // Note: RSSI is not directly available from NEHotspotNetwork
                    // We'll use a simulated value or get it from other sources
                    completion(network.ssid, network.bssid, self.estimateRSSI())
                } else {
                    // Fallback to legacy method
                    Task { @MainActor in
                        self.fetchWiFiInfoLegacy(completion: completion)
                    }
                }
            }
        } else {
            fetchWiFiInfoLegacy(completion: completion)
        }
    }

    @MainActor
    private func fetchWiFiInfoLegacy(completion: @escaping (String?, String?, Int?) -> Void) {
        // Legacy method using CNCopyCurrentNetworkInfo
        var ssid: String?
        var bssid: String?

        if let interfaces = CNCopySupportedInterfaces() as? [String] {
            for interface in interfaces {
                if let networkInfo = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any] {
                    ssid = networkInfo[kCNNetworkInfoKeySSID as String] as? String
                    bssid = networkInfo[kCNNetworkInfoKeyBSSID as String] as? String
                    break
                }
            }
        }

        completion(ssid, bssid, estimateRSSI())
    }

    /// Estimate RSSI (actual RSSI requires private APIs or CoreWLAN on macOS)
    /// On iOS, we can't get real RSSI without private APIs
    /// This returns a simulated value for demonstration
    nonisolated private func estimateRSSI() -> Int {
        // In a real app, you might:
        // 1. Use private APIs (not App Store safe)
        // 2. Use a network speed test as proxy
        // 3. Request from a companion macOS app

        // For now, return a random value in typical range for demonstration
        // In production, you'd want actual signal data
        return Int.random(in: -80 ... -40)
    }
}

// MARK: - CLLocationManagerDelegate

extension WiFiSignalManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let wasAuthorized = self.isAuthorized
            self.updateAuthorizationStatus()

            // Auto-enable if permission was just granted and we were pending
            if !wasAuthorized && self.isAuthorized && self.pendingEnable {
                self.pendingEnable = false
                self.isEnabled = true
                // Notify observers that we're now enabled
                NotificationCenter.default.post(name: .wifiTrackingDidEnable, object: nil)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            let wasAuthorized = self.isAuthorized
            self.updateAuthorizationStatus()

            // Auto-enable if permission was just granted and we were pending
            if !wasAuthorized && self.isAuthorized && self.pendingEnable {
                self.pendingEnable = false
                self.isEnabled = true
                // Notify observers that we're now enabled
                NotificationCenter.default.post(name: .wifiTrackingDidEnable, object: nil)
            }
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let wifiTrackingDidEnable = Notification.Name("wifiTrackingDidEnable")
}

// MARK: - WiFi Sample Statistics

extension Array where Element == WiFiSample {

    /// Average signal strength
    var averageRSSI: Int? {
        guard !isEmpty else { return nil }
        let sum = reduce(0) { $0 + $1.rssi }
        return sum / count
    }

    /// Minimum signal strength (weakest)
    var minRSSI: Int? {
        self.min(by: { $0.rssi < $1.rssi })?.rssi
    }

    /// Maximum signal strength (strongest)
    var maxRSSI: Int? {
        self.max(by: { $0.rssi < $1.rssi })?.rssi
    }

    /// Group samples by signal quality
    var qualityDistribution: [WiFiSample.SignalQuality: Int] {
        var distribution: [WiFiSample.SignalQuality: Int] = [:]
        for sample in self {
            distribution[sample.signalQuality, default: 0] += 1
        }
        return distribution
    }

    /// Summary string
    var summary: String {
        guard !isEmpty else { return "No WiFi data" }

        var parts: [String] = []
        parts.append("\(count) samples")

        if let avg = averageRSSI {
            parts.append("avg: \(avg) dBm")
        }
        if let min = minRSSI, let max = maxRSSI {
            parts.append("range: \(min) to \(max) dBm")
        }

        return parts.joined(separator: ", ")
    }
}
