/*
See LICENSE folder for this sample's licensing information.

Abstract:
Centralized constants and configuration values (Issue #19).
*/

import UIKit

// MARK: - App Constants (Issue #19)

enum AppConstants {

    // MARK: - UI Configuration

    enum UI {
        static let animationDuration: TimeInterval = 0.3
        static let statusLabelAutoHideDelay: TimeInterval = 2.0
        static let cornerRadius: CGFloat = 8.0
        static let statusLabelFontSize: CGFloat = 14.0
        static let statusLabelMinHeight: CGFloat = 32.0
        static let statusLabelTopOffset: CGFloat = 50.0
        static let overlayAlpha: CGFloat = 0.6
        static let errorOverlayAlpha: CGFloat = 0.8
    }

    // MARK: - Colors

    enum Colors {
        static let overlayBackground = UIColor.black.withAlphaComponent(UI.overlayAlpha)
        static let errorBackground = UIColor.systemRed.withAlphaComponent(UI.errorOverlayAlpha)
        static let activeNavBarTint = UIColor.white
        static let completeNavBarTint = UIColor.systemBlue
    }

    // MARK: - Export Configuration

    enum Export {
        static let filePrefix = "Room"
        static let dateFormat = "yyyyMMdd_HHmmss"
        static let fileExtension = "usdz"
    }

    // MARK: - Strings

    enum Strings {
        static let exportTitle = "Export Room Scan"
        static let exportMessage = "Choose export format:"
        static let errorTitle = "Error"
        static let cancelButton = "Cancel"
        static let okButton = "OK"
        static let tryAgainButton = "Try Again"
        static let scanningStarted = "Scanning started"
        static let scanningFailed = "Scanning failed"
        static let scanEndedWithError = "Scan ended with error"
        static let noElementsDetected = "No elements detected"
        static let unsupportedDeviceTitle = "Unsupported Device"
        static let unsupportedDeviceMessage = "This device doesn't have a LiDAR scanner. RoomPlan requires iPhone 12 Pro or later, or iPad Pro with LiDAR."
        static let deviceNotSupported = "Device Not Supported"
        static let unableToStartScanning = "Unable to start scanning. Please restart the app."
    }
}
