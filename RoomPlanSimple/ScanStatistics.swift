/*
See LICENSE folder for this sample's licensing information.

Abstract:
Scan statistics and room geometry utilities (Issue #14 - extracted component).
*/

import RoomPlan

// MARK: - Scan Statistics

struct ScanStatistics: Sendable {
    var wallCount: Int = 0
    var doorCount: Int = 0
    var windowCount: Int = 0
    var objectCount: Int = 0
    var openingCount: Int = 0
    var floorArea: Float = 0

    var totalElements: Int {
        wallCount + doorCount + windowCount + objectCount + openingCount
    }

    var summary: String {
        var parts: [String] = []
        if wallCount > 0 { parts.append("\(wallCount) wall\(wallCount == 1 ? "" : "s")") }
        if doorCount > 0 { parts.append("\(doorCount) door\(doorCount == 1 ? "" : "s")") }
        if windowCount > 0 { parts.append("\(windowCount) window\(windowCount == 1 ? "" : "s")") }
        if objectCount > 0 { parts.append("\(objectCount) object\(objectCount == 1 ? "" : "s")") }
        if floorArea > 0 { parts.append(String(format: "%.1f m² floor", floorArea)) }
        return parts.isEmpty ? AppConstants.Strings.noElementsDetected : parts.joined(separator: ", ")
    }

    static func from(_ room: CapturedRoom) -> ScanStatistics {
        var stats = ScanStatistics()
        stats.wallCount = room.walls.count
        stats.doorCount = room.doors.count
        stats.windowCount = room.windows.count
        stats.openingCount = room.openings.count
        stats.objectCount = room.objects.count
        stats.floorArea = RoomGeometry.calculateApproximateFloorArea(from: room)
        return stats
    }
}

// MARK: - Room Geometry Utilities (Issue #19)

enum RoomGeometry {

    /// Calculate approximate floor area from room walls
    static func calculateApproximateFloorArea(from room: CapturedRoom) -> Float {
        guard !room.walls.isEmpty else { return 0 }

        // Get bounding box from wall positions
        var minX: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var minZ: Float = .greatestFiniteMagnitude
        var maxZ: Float = -.greatestFiniteMagnitude

        for wall in room.walls {
            let position = wall.transform.columns.3
            let halfWidth = wall.dimensions.x / 2

            minX = min(minX, position.x - halfWidth)
            maxX = max(maxX, position.x + halfWidth)
            minZ = min(minZ, position.z - halfWidth)
            maxZ = max(maxZ, position.z + halfWidth)
        }

        let width = maxX - minX
        let depth = maxZ - minZ

        return width * depth
    }

    /// Get room bounding box dimensions
    static func getBoundingBox(from room: CapturedRoom) -> (width: Float, height: Float, depth: Float) {
        guard !room.walls.isEmpty else { return (0, 0, 0) }

        var minX: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var minY: Float = .greatestFiniteMagnitude
        var maxY: Float = -.greatestFiniteMagnitude
        var minZ: Float = .greatestFiniteMagnitude
        var maxZ: Float = -.greatestFiniteMagnitude

        for wall in room.walls {
            let position = wall.transform.columns.3
            let halfDim = wall.dimensions / 2

            minX = min(minX, position.x - halfDim.x)
            maxX = max(maxX, position.x + halfDim.x)
            minY = min(minY, position.y - halfDim.y)
            maxY = max(maxY, position.y + halfDim.y)
            minZ = min(minZ, position.z - halfDim.z)
            maxZ = max(maxZ, position.z + halfDim.z)
        }

        return (
            width: maxX - minX,
            height: maxY - minY,
            depth: maxZ - minZ
        )
    }

    /// Get center point of room
    static func getRoomCenter(from room: CapturedRoom) -> SIMD3<Float>? {
        guard !room.walls.isEmpty else { return nil }

        var sum = SIMD3<Float>.zero
        for wall in room.walls {
            sum += SIMD3<Float>(
                wall.transform.columns.3.x,
                wall.transform.columns.3.y,
                wall.transform.columns.3.z
            )
        }

        return sum / Float(room.walls.count)
    }
}
