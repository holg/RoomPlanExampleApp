/*
See LICENSE folder for this sample's licensing information.

Abstract:
Manages saving and loading of scanned room data for later export.
*/

import Foundation
import UIKit
import RoomPlan
import ModelIO

/// Manages persistent storage of captured room scans
@MainActor
final class RoomStorageManager {

    static let shared = RoomStorageManager()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Directory for saved rooms - uses iCloud if enabled, otherwise local storage
    private var savedRoomsDirectory: URL {
        let baseDir: URL

        // Use iCloud if enabled and available
        if AppSettings.shared.iCloudSyncEnabled,
           let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil) {
            baseDir = iCloudURL.appendingPathComponent("Documents")
            #if DEBUG
            print("✅ Using iCloud directory: \(baseDir.path)")
            #endif
        } else {
            // Use Application Support (persists across app updates, not backed up by default)
            baseDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            #if DEBUG
            print("💾 Using local directory: \(baseDir.path)")
            #endif
        }

        let roomsDir = baseDir.appendingPathComponent("SavedRooms", isDirectory: true)

        if !fileManager.fileExists(atPath: roomsDir.path) {
            do {
                try fileManager.createDirectory(at: roomsDir, withIntermediateDirectories: true)
                #if DEBUG
                print("📁 Created SavedRooms directory at: \(roomsDir.path)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to create directory: \(error)")
                #endif
            }
        }

        #if DEBUG
        print("📂 SavedRooms directory: \(roomsDir.path)")
        print("📊 iCloud enabled: \(AppSettings.shared.iCloudSyncEnabled)")
        print("☁️  iCloud available: \(AppSettings.shared.isICloudAvailable)")
        #endif

        return roomsDir
    }

    private init() {}

    // MARK: - Public API

    /// Save a captured room with metadata and floor plan image
    func saveRoom(_ room: CapturedRoom, name: String? = nil, photoManager: PhotoCaptureManager? = nil) throws -> SavedRoom {
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

        // Save floor plan data for SVG/DXF export
        let floorPlanData = FloorPlanData.from(room)
        let floorPlanDataFileName = "\(id.uuidString)_floorplan.json"
        let floorPlanDataURL = savedRoomsDirectory.appendingPathComponent(floorPlanDataFileName)
        if let data = try? encoder.encode(floorPlanData) {
            try? data.write(to: floorPlanDataURL)
        }

        // Save photos if photo manager provided
        if let photoManager = photoManager, photoManager.photoCount > 0 {
            do {
                let roomDirectory = savedRoomsDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
                _ = try photoManager.copyPhotos(to: roomDirectory)
                #if DEBUG
                print("📸 Saved \(photoManager.photoCount) photos to \(roomDirectory.path)")
                #endif
            } catch {
                #if DEBUG
                print("⚠️  Failed to save photos: \(error)")
                #endif
            }
        }

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
        let directory = savedRoomsDirectory

        #if DEBUG
        print("📁 Loading saved rooms from: \(directory.path)")
        #endif

        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            #if DEBUG
            print("⚠️  Could not read directory contents")
            #endif
            return []
        }

        #if DEBUG
        print("📄 Found \(files.count) files in directory")
        let jsonFiles = files.filter { $0.pathExtension == "json" }
        print("📋 Found \(jsonFiles.count) JSON files")
        #endif

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> SavedRoom? in
                guard let data = try? Data(contentsOf: url),
                      let room = try? decoder.decode(SavedRoom.self, from: data) else {
                    #if DEBUG
                    print("⚠️  Failed to decode room from: \(url.lastPathComponent)")
                    #endif
                    return nil
                }
                return room
            }
            .sorted { $0.date > $1.date }
    }

    /// Note: CapturedRoom cannot be reloaded from USDZ files.
    /// This is a limitation of the RoomPlan API - CapturedRoom is only available during live scanning.
    /// To view saved rooms, use the USDZ file directly with SceneKit.

    /// Load WiFi samples for a saved room
    func loadWiFiSamples(for room: SavedRoom) -> [WiFiSample] {
        let wifiURL = savedRoomsDirectory.appendingPathComponent("\(room.id.uuidString)_wifi.json")
        guard let data = try? Data(contentsOf: wifiURL),
              let samples = try? decoder.decode([WiFiSample].self, from: data) else {
            return []
        }
        return samples
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

    /// Export saved room to OBJ format
    func exportToOBJ(for room: SavedRoom) throws -> URL {
        let usdzURL = getUsdzURL(for: room)
        guard fileManager.fileExists(atPath: usdzURL.path) else {
            throw NSError(domain: "RoomStorageManager", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "USDZ file not found"])
        }

        let objFileName = "\(room.id.uuidString).obj"
        let objURL = fileManager.temporaryDirectory.appendingPathComponent(objFileName)

        // Clean up any existing file
        try? fileManager.removeItem(at: objURL)

        // Load USDZ with ModelIO
        let asset = MDLAsset(url: usdzURL)

        // Export to OBJ
        try asset.export(to: objURL)

        return objURL
    }

    /// Export saved room to STL format
    func exportToSTL(for room: SavedRoom) throws -> URL {
        let usdzURL = getUsdzURL(for: room)
        guard fileManager.fileExists(atPath: usdzURL.path) else {
            throw NSError(domain: "RoomStorageManager", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "USDZ file not found"])
        }

        let stlFileName = "\(room.id.uuidString).stl"
        let stlURL = fileManager.temporaryDirectory.appendingPathComponent(stlFileName)

        // Clean up any existing file
        try? fileManager.removeItem(at: stlURL)

        // Load USDZ with ModelIO
        let asset = MDLAsset(url: usdzURL)

        // Export to STL
        try asset.export(to: stlURL)

        return stlURL
    }

    /// Load floor plan data for a saved room
    func loadFloorPlanData(for room: SavedRoom) -> FloorPlanData? {
        let dataURL = savedRoomsDirectory.appendingPathComponent("\(room.id.uuidString)_floorplan.json")
        guard let data = try? Data(contentsOf: dataURL),
              let floorPlanData = try? decoder.decode(FloorPlanData.self, from: data) else {
            return nil
        }
        return floorPlanData
    }

    /// Export saved room floor plan to SVG format
    func exportToSVG(for room: SavedRoom) throws -> URL {
        guard let floorPlanData = loadFloorPlanData(for: room) else {
            throw NSError(domain: "RoomStorageManager", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Floor plan data not found"])
        }

        let svgFileName = "\(room.id.uuidString).svg"
        let svgURL = fileManager.temporaryDirectory.appendingPathComponent(svgFileName)

        // Clean up any existing file
        try? fileManager.removeItem(at: svgURL)

        // Generate SVG
        let svgContent = FloorPlanExporter.exportToSVG(data: floorPlanData, includeDimensions: true)
        try svgContent.write(to: svgURL, atomically: true, encoding: .utf8)

        return svgURL
    }

    /// Export saved room floor plan to DXF format
    func exportToDXF(for room: SavedRoom) throws -> URL {
        guard let floorPlanData = loadFloorPlanData(for: room) else {
            throw NSError(domain: "RoomStorageManager", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Floor plan data not found"])
        }

        let dxfFileName = "\(room.id.uuidString).dxf"
        let dxfURL = fileManager.temporaryDirectory.appendingPathComponent(dxfFileName)

        // Clean up any existing file
        try? fileManager.removeItem(at: dxfURL)

        // Generate DXF
        let dxfContent = FloorPlanExporter.exportToDXF(data: floorPlanData, includeDimensions: true)
        try dxfContent.write(to: dxfURL, atomically: true, encoding: .utf8)

        return dxfURL
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

    // MARK: - Debug Helpers

    #if DEBUG
    /// Print detailed information about storage locations and contents
    func debugStorageInfo() {
        print("\n" + String(repeating: "=", count: 60))
        print("📊 STORAGE DEBUG INFO")
        print(String(repeating: "=", count: 60))

        // iCloud availability
        print("\n☁️  iCloud Status:")
        print("   - iCloud available: \(AppSettings.shared.isICloudAvailable)")
        print("   - iCloud enabled in app: \(AppSettings.shared.iCloudSyncEnabled)")
        if let token = fileManager.ubiquityIdentityToken {
            print("   - iCloud identity token: \(token)")
        } else {
            print("   - ⚠️  No iCloud identity token (not signed in)")
        }

        // Current directory
        print("\n📂 Current SavedRooms Directory:")
        print("   \(savedRoomsDirectory.path)")

        // Directory contents
        if let files = try? fileManager.contentsOfDirectory(at: savedRoomsDirectory, includingPropertiesForKeys: nil) {
            print("\n📄 Files in directory: \(files.count)")
            for file in files {
                let fileSize = (try? fileManager.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0
                let sizeStr = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                print("   - \(file.lastPathComponent) (\(sizeStr))")
            }
        } else {
            print("\n⚠️  Could not read directory")
        }

        // Alternative directories
        print("\n📁 Other Storage Locations:")
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appSupportRooms = appSupport.appendingPathComponent("SavedRooms")
        print("   Local (App Support): \(appSupportRooms.path)")
        if fileManager.fileExists(atPath: appSupportRooms.path) {
            if let localFiles = try? fileManager.contentsOfDirectory(at: appSupportRooms, includingPropertiesForKeys: nil) {
                print("   → Contains \(localFiles.count) files")
            }
        } else {
            print("   → Does not exist")
        }

        if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil) {
            let iCloudRooms = iCloudURL.appendingPathComponent("Documents/SavedRooms")
            print("   iCloud: \(iCloudRooms.path)")
            if fileManager.fileExists(atPath: iCloudRooms.path) {
                if let iCloudFiles = try? fileManager.contentsOfDirectory(at: iCloudRooms, includingPropertiesForKeys: nil) {
                    print("   → Contains \(iCloudFiles.count) files")
                }
            } else {
                print("   → Does not exist yet")
            }
        } else {
            print("   iCloud: Not available")
        }

        print(String(repeating: "=", count: 60) + "\n")
    }
    #endif

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
