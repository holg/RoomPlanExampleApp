/*
See LICENSE folder for this sample's licensing information.

Abstract:
Unit tests for RoomCaptureError types.
*/

import XCTest
@testable import RoomPlanSimple

final class RoomCaptureErrorTests: XCTestCase {

    // MARK: - Error Description Tests

    func testNoScanDataErrorDescription() {
        let error = RoomCaptureError.noScanData
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testExportFailedErrorDescription() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error = RoomCaptureError.exportFailed(underlying: underlying)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("export"))
    }

    func testSessionFailedErrorDescription() {
        let underlying = NSError(domain: "test", code: 2, userInfo: nil)
        let error = RoomCaptureError.sessionFailed(underlying: underlying)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.lowercased().contains("session"))
    }

    func testProcessingFailedErrorDescription() {
        let underlying = NSError(domain: "test", code: 3, userInfo: nil)
        let error = RoomCaptureError.processingFailed(underlying: underlying)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.lowercased().contains("process"))
    }

    func testDeviceNotSupportedErrorDescription() {
        let error = RoomCaptureError.deviceNotSupported
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.lowercased().contains("support"))
    }

    // MARK: - Recovery Suggestion Tests

    func testAllErrorsHaveRecoverySuggestions() {
        let errors: [RoomCaptureError] = [
            .noScanData,
            .exportFailed(underlying: NSError(domain: "", code: 0)),
            .sessionFailed(underlying: NSError(domain: "", code: 0)),
            .processingFailed(underlying: NSError(domain: "", code: 0)),
            .deviceNotSupported
        ]

        for error in errors {
            XCTAssertNotNil(error.recoverySuggestion, "Missing recovery suggestion for \(error)")
            XCTAssertFalse(error.recoverySuggestion!.isEmpty, "Empty recovery suggestion for \(error)")
        }
    }

    // MARK: - Export Format Tests

    func testExportFormatCases() {
        XCTAssertEqual(ExportFormat.allCases.count, 2)
        XCTAssertTrue(ExportFormat.allCases.contains(.parametric))
        XCTAssertTrue(ExportFormat.allCases.contains(.mesh))
    }

    func testExportFormatFileExtension() {
        for format in ExportFormat.allCases {
            XCTAssertEqual(format.fileExtension, "usdz")
        }
    }

    func testExportFormatRawValues() {
        XCTAssertFalse(ExportFormat.parametric.rawValue.isEmpty)
        XCTAssertFalse(ExportFormat.mesh.rawValue.isEmpty)
    }
}
