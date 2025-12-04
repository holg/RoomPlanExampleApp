/*
See LICENSE folder for this sample's licensing information.

Abstract:
App settings manager using UserDefaults.
*/

import Foundation

/// Manages app settings using UserDefaults
final class AppSettings {

    // MARK: - Singleton

    static let shared = AppSettings()
    private init() {}

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let autoSaveScans = "autoSaveScans"
        static let defaultWifiTracking = "defaultWifiTracking"
        static let defaultExportFormat = "defaultExportFormat"
        static let showPhotosInFloorPlan = "showPhotosInFloorPlan"
    }

    // MARK: - Settings Properties

    /// Automatically save scans when completed (default: true)
    var autoSaveScans: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.autoSaveScans) == nil {
                return true  // Default to true
            }
            return UserDefaults.standard.bool(forKey: Keys.autoSaveScans)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.autoSaveScans)
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }
    }

    /// Enable WiFi tracking by default when starting a scan
    var defaultWifiTracking: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.defaultWifiTracking) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.defaultWifiTracking)
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }
    }

    /// Default export format
    var defaultExportFormat: String {
        get { UserDefaults.standard.string(forKey: Keys.defaultExportFormat) ?? "parametric" }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.defaultExportFormat)
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }
    }

    /// Show photos overlay in floor plan
    var showPhotosInFloorPlan: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.showPhotosInFloorPlan) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showPhotosInFloorPlan)
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }
    }

    // MARK: - Reset

    /// Reset all settings to defaults
    func resetToDefaults() {
        autoSaveScans = true
        defaultWifiTracking = false
        defaultExportFormat = "parametric"
        showPhotosInFloorPlan = false
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
}
