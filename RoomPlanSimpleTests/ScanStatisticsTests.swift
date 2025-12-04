/*
See LICENSE folder for this sample's licensing information.

Abstract:
Unit tests for ScanStatistics and RoomGeometry utilities.
*/

import XCTest
@testable import RoomPlanSimple

final class ScanStatisticsTests: XCTestCase {

    // MARK: - ScanStatistics Tests

    func testEmptyStatisticsSummary() {
        let stats = ScanStatistics()
        XCTAssertEqual(stats.summary, AppConstants.Strings.noElementsDetected)
    }

    func testStatisticsSummaryWithWalls() {
        var stats = ScanStatistics()
        stats.wallCount = 4
        XCTAssertTrue(stats.summary.contains("4 walls"))
    }

    func testStatisticsSummarySingular() {
        var stats = ScanStatistics()
        stats.wallCount = 1
        stats.doorCount = 1
        XCTAssertTrue(stats.summary.contains("1 wall"))
        XCTAssertTrue(stats.summary.contains("1 door"))
        XCTAssertFalse(stats.summary.contains("walls"))
    }

    func testStatisticsSummaryWithFloorArea() {
        var stats = ScanStatistics()
        stats.floorArea = 25.5
        XCTAssertTrue(stats.summary.contains("25.5 m²"))
    }

    func testStatisticsSummaryMultipleElements() {
        var stats = ScanStatistics()
        stats.wallCount = 4
        stats.doorCount = 2
        stats.windowCount = 3
        stats.objectCount = 5

        let summary = stats.summary
        XCTAssertTrue(summary.contains("4 walls"))
        XCTAssertTrue(summary.contains("2 doors"))
        XCTAssertTrue(summary.contains("3 windows"))
        XCTAssertTrue(summary.contains("5 objects"))
    }

    func testTotalElements() {
        var stats = ScanStatistics()
        stats.wallCount = 4
        stats.doorCount = 2
        stats.windowCount = 1
        stats.objectCount = 3
        stats.openingCount = 2

        XCTAssertEqual(stats.totalElements, 12)
    }

    func testTotalElementsEmpty() {
        let stats = ScanStatistics()
        XCTAssertEqual(stats.totalElements, 0)
    }
}
