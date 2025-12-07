/*
See LICENSE folder for this sample's licensing information.

Abstract:
Helper for localization support
*/

import Foundation

/// Helper extension for easy string localization
extension String {
    /// Returns the localized string for the given key
    var localized: String {
        return NSLocalizedString(self, tableName: "Localizable", bundle: Bundle.main, value: self, comment: "")
    }

    /// Returns the localized string with formatted arguments
    func localized(_ arguments: CVarArg...) -> String {
        let format = self.localized
        return String(format: format, arguments: arguments)
    }
}

/// Localization keys namespace
enum L10n {
    // MARK: - Common
    enum Common {
        static let ok = "common.ok"
        static let cancel = "common.cancel"
        static let done = "common.done"
        static let save = "common.save"
        static let delete = "common.delete"
        static let edit = "common.edit"
        static let close = "common.close"
        static let share = "common.share"
        static let error = "common.error"
        static let success = "common.success"
        static let loading = "common.loading"
    }

    // MARK: - Home
    enum Home {
        static let title = "home.title"
        static let header = "home.header"
        static let recentScans = "home.recentScans"
        static let emptyState = "home.emptyState"
        static let features = "home.features"

        enum NewScan {
            static let title = "home.newScan.title"
            static let subtitle = "home.newScan.subtitle"
            static let noLidar = "home.newScan.noLidar"
        }

        enum SavedRooms {
            static let title = "home.savedRooms.title"
            static let subtitle = "home.savedRooms.subtitle"
            static let count = "home.savedRooms.count"
            static let room = "home.savedRooms.room"
            static let rooms = "home.savedRooms.rooms"
        }

        enum Help {
            static let title = "home.help.title"
            static let subtitle = "home.help.subtitle"
        }
    }

    // MARK: - Features
    enum Feature {
        static let capture3DTitle = "feature.3dCapture.title"
        static let capture3DDescription = "feature.3dCapture.description"
        static let wifiHeatmapTitle = "feature.wifiHeatmap.title"
        static let wifiHeatmapDescription = "feature.wifiHeatmap.description"
        static let photoCaptureTitle = "feature.photoCapture.title"
        static let photoCaptureDescription = "feature.photoCapture.description"
        static let exportTitle = "feature.export.title"
        static let exportDescription = "feature.export.description"
        static let icloudTitle = "feature.icloud.title"
        static let icloudDescription = "feature.icloud.description"
    }

    // MARK: - Scanning
    enum Scan {
        static let title = "scan.title"
        static let preparing = "scan.preparing"
        static let instructions = "scan.instructions"
        static let wifiTracking = "scan.wifiTracking"
        static let photosTaken = "scan.photosTaken"
        static let duration = "scan.duration"
        static let done = "scan.done"
        static let cancel = "scan.cancel"
        static let processing = "scan.processing"
        static let saving = "scan.saving"
        static let autoSaved = "scan.autoSaved"
        static let saveSuccess = "scan.saveSuccess"

        enum Error {
            static let title = "scan.error.title"
            static let sessionFailed = "scan.error.sessionFailed"
            static let exportFailed = "scan.error.exportFailed"
            static let saveFailed = "scan.error.saveFailed"
        }
    }

    // MARK: - Saved Rooms
    enum SavedRooms {
        static let title = "savedRooms.title"
        static let empty = "savedRooms.empty"
        static let walls = "savedRooms.walls"
        static let doors = "savedRooms.doors"
        static let windows = "savedRooms.windows"
        static let objects = "savedRooms.objects"
        static let area = "savedRooms.area"
        static let dimensions = "savedRooms.dimensions"
        static let deleteSuccess = "savedRooms.deleteSuccess"
        static let deleteError = "savedRooms.deleteError"
        static let selectRooms = "savedRooms.selectRooms"
        static let selectedCount = "savedRooms.selectedCount"
        static let deleteSelected = "savedRooms.deleteSelected"
        static let exportSelected = "savedRooms.exportSelected"

        enum DeleteConfirm {
            static let title = "savedRooms.deleteConfirm.title"
            static let message = "savedRooms.deleteConfirm.message"
            static let delete = "savedRooms.deleteConfirm.delete"
        }

        enum DeleteAll {
            static let title = "savedRooms.deleteAll.title"
            static let message = "savedRooms.deleteAll.message"
            static let button = "savedRooms.deleteAll.button"
        }

        enum DeleteSelected {
            static let title = "savedRooms.deleteSelected.title"
            static let message = "savedRooms.deleteSelected.message"
        }
    }

    // MARK: - Room Viewer
    enum Viewer {
        static let title = "viewer.title"
        static let export = "viewer.export"
        static let noFloorPlan = "viewer.noFloorPlan"
        static let no3DModel = "viewer.no3DModel"
        static let noWifiData = "viewer.noWifiData"
        static let floorPlanHint = "viewer.floorPlanHint"
        static let model3DHint = "viewer.model3DHint"
        static let photosPlaceholder = "viewer.photosPlaceholder"
        static let wifiSamplesCount = "viewer.wifiSamplesCount"
        static let photos = "viewer.mode.photos"

        enum Mode {
            static let info = "viewer.mode.info"
            static let model3D = "viewer.mode.3d"
            static let floorPlan = "viewer.mode.floorPlan"
            static let wifi = "viewer.mode.wifi"
            static let photos = "viewer.mode.photos"
        }

        enum Info {
            static let name = "viewer.info.name"
            static let date = "viewer.info.date"
            static let dimensions = "viewer.info.dimensions"
            static let area = "viewer.info.area"
            static let walls = "viewer.info.walls"
            static let doors = "viewer.info.doors"
            static let windows = "viewer.info.windows"
            static let objects = "viewer.info.objects"
        }
    }

    // MARK: - Export
    enum Export {
        static let title = "export.title"
        static let format = "export.format"
        static let usdz = "export.usdz"
        static let obj = "export.obj"
        static let stl = "export.stl"
        static let dxf = "export.dxf"
        static let svg = "export.svg"
        static let png = "export.png"
        static let processing = "export.processing"
        static let success = "export.success"
        static let error = "export.error"
        static let share = "export.share"
        static let chooseExport = "export.chooseExport"
        static let floorPlanImage = "export.floorPlanImage"
        static let both = "export.both"
    }

    // MARK: - Settings
    enum Settings {
        static let title = "settings.title"
        static let scanning = "settings.scanning"
        static let saving = "settings.saving"
        static let language = "settings.language"
        static let about = "settings.about"
        static let version = "settings.version"
        static let reset = "settings.reset"

        enum WiFiTracking {
            static let title = "settings.wifiTracking.title"
            static let subtitle = "settings.wifiTracking.subtitle"
        }

        enum AutoSave {
            static let title = "settings.autoSave.title"
            static let subtitle = "settings.autoSave.subtitle"
        }

        enum ICloud {
            static let title = "settings.icloud.title"
            static let subtitle = "settings.icloud.subtitle"
            static let unavailable = "settings.icloud.unavailable"
            static let notAvailableTitle = "settings.icloud.notAvailable.title"
            static let notAvailableMessage = "settings.icloud.notAvailable.message"
        }

        enum AppLanguage {
            static let title = "settings.appLanguage.title"
            static let subtitle = "settings.appLanguage.subtitle"
            static let systemDefault = "settings.appLanguage.systemDefault"
        }

        enum ResetConfirm {
            static let title = "settings.reset.confirm.title"
            static let message = "settings.reset.confirm.message"
            static let reset = "settings.reset.confirm.reset"
        }

        enum LanguageRestart {
            static let title = "settings.language.restart.title"
            static let message = "settings.language.restart.message"
            static let restartNow = "settings.language.restart.restartNow"
        }
    }

    // MARK: - Help
    enum Help {
        static let title = "help.title"
        static let gettingStarted = "help.gettingStarted"
        static let icloudSetup = "help.icloudSetup"
        static let scanning = "help.scanning"
        static let viewing = "help.viewing"
        static let exporting = "help.exporting"
        static let troubleshooting = "help.troubleshooting"
    }

    // MARK: - Alerts
    enum Alert {
        static let unsupportedDeviceTitle = "alert.unsupportedDevice.title"
        static let unsupportedDeviceMessage = "alert.unsupportedDevice.message"
        static let scanningUnavailable = "alert.scanningUnavailable"
    }

    // MARK: - Floor Plan
    enum FloorPlan {
        static let title = "floorPlan.title"
        static let dimensions = "floorPlan.dimensions"
        static let measurements = "floorPlan.measurements"
        static let error = "floorPlan.error"
        static let view = "floorPlan.view"
        static let notFound = "floorPlan.notFound"
    }

    // MARK: - WiFi
    enum WiFi {
        static let title = "wifi.title"
        static let signalStrength = "wifi.signalStrength"
        static let excellent = "wifi.excellent"
        static let good = "wifi.good"
        static let fair = "wifi.fair"
        static let poor = "wifi.poor"
        static let noData = "wifi.noData"
    }

    // MARK: - Onboarding
    enum Onboarding {
        static let welcome = "onboarding.welcome"
        static let feature1Title = "onboarding.feature1.title"
        static let feature1Description = "onboarding.feature1.description"
        static let feature2Title = "onboarding.feature2.title"
        static let feature2Description = "onboarding.feature2.description"
        static let feature3Title = "onboarding.feature3.title"
        static let feature3Description = "onboarding.feature3.description"
        static let getStarted = "onboarding.getStarted"
        static let skip = "onboarding.skip"
    }

    // MARK: - Statistics
    enum Stats {
        static let empty = "stats.empty"
        static let wallCount = "stats.wallCount"
        static let doorCount = "stats.doorCount"
        static let windowCount = "stats.windowCount"
        static let objectCount = "stats.objectCount"
        static let floorArea = "stats.floorArea"
        static let roomDimensions = "stats.roomDimensions"
    }
}
