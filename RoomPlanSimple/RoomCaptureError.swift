/*
See LICENSE folder for this sample's licensing information.

Abstract:
Error types for room capture operations (Issue #16).
*/

import Foundation

// MARK: - Room Capture Error Types

enum RoomCaptureError: LocalizedError {
    case noScanData
    case exportFailed(underlying: Error)
    case sessionFailed(underlying: Error)
    case processingFailed(underlying: Error)
    case deviceNotSupported

    var errorDescription: String? {
        switch self {
        case .noScanData:
            return "No room scan data available"
        case .exportFailed(let error):
            return "Failed to export room: \(error.localizedDescription)"
        case .sessionFailed(let error):
            return "Scanning session failed: \(error.localizedDescription)"
        case .processingFailed(let error):
            return "Failed to process scan: \(error.localizedDescription)"
        case .deviceNotSupported:
            return "This device does not support room scanning"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noScanData:
            return "Please complete a room scan before exporting."
        case .exportFailed:
            return "Try exporting again or use a different format."
        case .sessionFailed:
            return "Ensure you have adequate lighting and try again."
        case .processingFailed:
            return "Try scanning the room again with slower movements."
        case .deviceNotSupported:
            return "RoomPlan requires iPhone 12 Pro or later, or iPad Pro with LiDAR."
        }
    }
}

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case parametric = "Parametric (Furniture)"
    case mesh = "3D Mesh"

    var exportOption: CapturedRoom.USDExportOptions {
        switch self {
        case .parametric: return .parametric
        case .mesh: return .mesh
        }
    }

    var fileExtension: String { AppConstants.Export.fileExtension }
}

import RoomPlan
