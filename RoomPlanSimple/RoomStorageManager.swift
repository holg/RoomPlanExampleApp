/*
See LICENSE folder for this sample's licensing information.

Abstract:
Manages saving and loading of scanned room data for later export.
*/

import Foundation
import UIKit
import RoomPlan

/// Manages persistent storage of captured room scans
@MainActor
final class RoomStorageManager {

    static let shared = RoomStorageManager()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var savedRoomsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let roomsDir = docs.appendingPathComponent("SavedRooms", isDirectory: true)

        if !fileManager.fileExists(atPath: roomsDir.path) {
            try? fileManager.createDirectory(at: roomsDir, withIntermediateDirectories: true)
        }
        return roomsDir
    }

    private init() {}

    // MARK: - Public API

    /// Save a captured room with metadata and floor plan image
    func saveRoom(_ room: CapturedRoom, name: String? = nil) throws -> SavedRoom {
        let id = UUID()
        let timestamp = Date()
        let roomName = name ?? "Room \(formatDate(timestamp))"

        // Export room to USDZ in saved rooms directory
        let usdzURL = savedRoomsDirectory.appendingPathComponent("\(id.uuidString).usdz")
        try room.export(to: usdzURL, exportOptions: .parametric)

        // Generate and save floor plan image
        let floorPlanFileName = "\(id.uuidString)_floorplan.png"
        let floorPlanURL = savedRoomsDirectory.appendingPathComponent(floorPlanFileName)
        saveFloorPlanImage(for: room, to: floorPlanURL)

        // Create metadata
        let stats = ScanStatistics.from(room)
        let metadata = SavedRoom(
            id: id,
            name: roomName,
            date: timestamp,
            wallCount: stats.wallCount,
            doorCount: stats.doorCount,
            windowCount: stats.windowCount,
            objectCount: stats.objectCount,
            floorArea: stats.floorArea,
            roomWidth: stats.roomWidth,
            roomHeight: stats.roomHeight,
            roomDepth: stats.roomDepth,
            usdzFileName: "\(id.uuidString).usdz",
            floorPlanFileName: floorPlanFileName
        )

        // Save metadata
        let metadataURL = savedRoomsDirectory.appendingPathComponent("\(id.uuidString).json")
        let data = try encoder.encode(metadata)
        try data.write(to: metadataURL)

        return metadata
    }

    private func saveFloorPlanImage(for room: CapturedRoom, to url: URL) {
        // Create a floor plan view and render to image
        let floorPlanView = FloorPlanView(frame: CGRect(x: 0, y: 0, width: 800, height: 800))
        floorPlanView.configure(with: room)
        floorPlanView.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(bounds: floorPlanView.bounds)
        let image = renderer.image { context in
            floorPlanView.layer.render(in: context.cgContext)
        }

        if let pngData = image.pngData() {
            try? pngData.write(to: url)
        }
    }

    /// Get all saved rooms
    func getSavedRooms() -> [SavedRoom] {
        guard let files = try? fileManager.contentsOfDirectory(at: savedRoomsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> SavedRoom? in
                guard let data = try? Data(contentsOf: url),
                      let room = try? decoder.decode(SavedRoom.self, from: data) else {
                    return nil
                }
                return room
            }
            .sorted { $0.date > $1.date }
    }

    /// Get USDZ file URL for a saved room
    func getUsdzURL(for room: SavedRoom) -> URL {
        savedRoomsDirectory.appendingPathComponent(room.usdzFileName)
    }

    /// Get floor plan image URL for a saved room
    func getFloorPlanURL(for room: SavedRoom) -> URL? {
        guard let fileName = room.floorPlanFileName else { return nil }
        let url = savedRoomsDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    /// Get floor plan image for a saved room
    func getFloorPlanImage(for room: SavedRoom) -> UIImage? {
        guard let url = getFloorPlanURL(for: room),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Delete a saved room
    func deleteRoom(_ room: SavedRoom) throws {
        let usdzURL = savedRoomsDirectory.appendingPathComponent(room.usdzFileName)
        let metadataURL = savedRoomsDirectory.appendingPathComponent("\(room.id.uuidString).json")

        try? fileManager.removeItem(at: usdzURL)
        try? fileManager.removeItem(at: metadataURL)

        // Also delete floor plan image
        if let floorPlanFileName = room.floorPlanFileName {
            let floorPlanURL = savedRoomsDirectory.appendingPathComponent(floorPlanFileName)
            try? fileManager.removeItem(at: floorPlanURL)
        }
    }

    /// Delete all saved rooms
    func deleteAllRooms() throws {
        let rooms = getSavedRooms()
        for room in rooms {
            try deleteRoom(room)
        }
    }

    // MARK: - Private

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - SavedRoom Model

struct SavedRoom: Codable, Identifiable {
    let id: UUID
    let name: String
    let date: Date
    let wallCount: Int
    let doorCount: Int
    let windowCount: Int
    let objectCount: Int
    let floorArea: Float
    let roomWidth: Float
    let roomHeight: Float
    let roomDepth: Float
    let usdzFileName: String
    let floorPlanFileName: String?

    // Support loading older saves without new fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        date = try container.decode(Date.self, forKey: .date)
        wallCount = try container.decode(Int.self, forKey: .wallCount)
        doorCount = try container.decode(Int.self, forKey: .doorCount)
        windowCount = try container.decode(Int.self, forKey: .windowCount)
        objectCount = try container.decode(Int.self, forKey: .objectCount)
        floorArea = try container.decode(Float.self, forKey: .floorArea)
        roomWidth = try container.decodeIfPresent(Float.self, forKey: .roomWidth) ?? 0
        roomHeight = try container.decodeIfPresent(Float.self, forKey: .roomHeight) ?? 0
        roomDepth = try container.decodeIfPresent(Float.self, forKey: .roomDepth) ?? 0
        usdzFileName = try container.decode(String.self, forKey: .usdzFileName)
        floorPlanFileName = try container.decodeIfPresent(String.self, forKey: .floorPlanFileName)
    }

    init(id: UUID, name: String, date: Date, wallCount: Int, doorCount: Int, windowCount: Int,
         objectCount: Int, floorArea: Float, roomWidth: Float, roomHeight: Float, roomDepth: Float,
         usdzFileName: String, floorPlanFileName: String?) {
        self.id = id
        self.name = name
        self.date = date
        self.wallCount = wallCount
        self.doorCount = doorCount
        self.windowCount = windowCount
        self.objectCount = objectCount
        self.floorArea = floorArea
        self.roomWidth = roomWidth
        self.roomHeight = roomHeight
        self.roomDepth = roomDepth
        self.usdzFileName = usdzFileName
        self.floorPlanFileName = floorPlanFileName
    }

    var summary: String {
        var parts: [String] = []
        if wallCount > 0 { parts.append("\(wallCount) walls") }
        if doorCount > 0 { parts.append("\(doorCount) doors") }
        if windowCount > 0 { parts.append("\(windowCount) windows") }
        if objectCount > 0 { parts.append("\(objectCount) objects") }
        if floorArea > 0 { parts.append(String(format: "%.1f m²", floorArea)) }
        return parts.isEmpty ? "Empty scan" : parts.joined(separator: ", ")
    }

    var dimensionsSummary: String {
        if roomWidth > 0 && roomDepth > 0 {
            return String(format: "%.1f × %.1f m", roomWidth, roomDepth)
        }
        return ""
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var hasFloorPlan: Bool {
        floorPlanFileName != nil
    }
}
