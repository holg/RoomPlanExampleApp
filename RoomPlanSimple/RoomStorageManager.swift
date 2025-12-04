/*
See LICENSE folder for this sample's licensing information.

Abstract:
Manages saving and loading of scanned room data for later export.
*/

import Foundation
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

    /// Save a captured room with metadata
    func saveRoom(_ room: CapturedRoom, name: String? = nil) throws -> SavedRoom {
        let id = UUID()
        let timestamp = Date()
        let roomName = name ?? "Room \(formatDate(timestamp))"

        // Export room to USDZ in saved rooms directory
        let usdzURL = savedRoomsDirectory.appendingPathComponent("\(id.uuidString).usdz")
        try room.export(to: usdzURL, exportOptions: .parametric)

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
            usdzFileName: "\(id.uuidString).usdz"
        )

        // Save metadata
        let metadataURL = savedRoomsDirectory.appendingPathComponent("\(id.uuidString).json")
        let data = try encoder.encode(metadata)
        try data.write(to: metadataURL)

        return metadata
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

    /// Delete a saved room
    func deleteRoom(_ room: SavedRoom) throws {
        let usdzURL = savedRoomsDirectory.appendingPathComponent(room.usdzFileName)
        let metadataURL = savedRoomsDirectory.appendingPathComponent("\(room.id.uuidString).json")

        try? fileManager.removeItem(at: usdzURL)
        try? fileManager.removeItem(at: metadataURL)
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
    let usdzFileName: String

    var summary: String {
        var parts: [String] = []
        if wallCount > 0 { parts.append("\(wallCount) walls") }
        if doorCount > 0 { parts.append("\(doorCount) doors") }
        if windowCount > 0 { parts.append("\(windowCount) windows") }
        if objectCount > 0 { parts.append("\(objectCount) objects") }
        if floorArea > 0 { parts.append(String(format: "%.1f m²", floorArea)) }
        return parts.isEmpty ? "Empty scan" : parts.joined(separator: ", ")
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
