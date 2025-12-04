/*
See LICENSE folder for this sample's licensing information.

Abstract:
Unit tests for AppConstants to ensure configuration values are sensible.
*/

import XCTest
@testable import RoomPlanSimple

final class ConstantsTests: XCTestCase {

    // MARK: - UI Constants Tests

    func testAnimationDurationIsPositive() {
        XCTAssertGreaterThan(AppConstants.UI.animationDuration, 0)
        XCTAssertLessThanOrEqual(AppConstants.UI.animationDuration, 1.0)
    }

    func testStatusLabelAutoHideDelayIsReasonable() {
        XCTAssertGreaterThanOrEqual(AppConstants.UI.statusLabelAutoHideDelay, 1.0)
        XCTAssertLessThanOrEqual(AppConstants.UI.statusLabelAutoHideDelay, 5.0)
    }

    func testCornerRadiusIsPositive() {
        XCTAssertGreaterThan(AppConstants.UI.cornerRadius, 0)
    }

    func testOverlayAlphaIsValid() {
        XCTAssertGreaterThan(AppConstants.UI.overlayAlpha, 0)
        XCTAssertLessThanOrEqual(AppConstants.UI.overlayAlpha, 1.0)
    }

    func testErrorOverlayAlphaIsValid() {
        XCTAssertGreaterThan(AppConstants.UI.errorOverlayAlpha, 0)
        XCTAssertLessThanOrEqual(AppConstants.UI.errorOverlayAlpha, 1.0)
    }

    // MARK: - Export Constants Tests

    func testExportFilePrefixNotEmpty() {
        XCTAssertFalse(AppConstants.Export.filePrefix.isEmpty)
    }

    func testExportDateFormatNotEmpty() {
        XCTAssertFalse(AppConstants.Export.dateFormat.isEmpty)
    }

    func testExportFileExtensionIsUSDZ() {
        XCTAssertEqual(AppConstants.Export.fileExtension, "usdz")
    }

    // MARK: - Strings Tests

    func testStringsNotEmpty() {
        XCTAssertFalse(AppConstants.Strings.exportTitle.isEmpty)
        XCTAssertFalse(AppConstants.Strings.errorTitle.isEmpty)
        XCTAssertFalse(AppConstants.Strings.cancelButton.isEmpty)
        XCTAssertFalse(AppConstants.Strings.okButton.isEmpty)
        XCTAssertFalse(AppConstants.Strings.unsupportedDeviceTitle.isEmpty)
        XCTAssertFalse(AppConstants.Strings.unsupportedDeviceMessage.isEmpty)
    }
}
