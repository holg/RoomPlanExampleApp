/*
See LICENSE folder for this sample's licensing information.

Abstract:
Manages capturing and storing reference photos during room scanning.
*/

import UIKit

/// Manages reference photo capture during room scanning
/// Photos are captured as screenshots of the RoomCaptureView
final class PhotoCaptureManager: NSObject, @unchecked Sendable {

    // MARK: - Types

    struct CapturedPhoto: Codable, Sendable {
        let id: UUID
        let timestamp: Date
        let fileName: String

        var formattedTime: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: timestamp)
        }
    }

    // MARK: - Properties

    private var capturedPhotos: [CapturedPhoto] = []
    private let lock = NSLock()

    // MARK: - Public API

    /// Start session (no-op, kept for compatibility)
    func startSession() {
        // No longer needed - we capture screenshots instead
    }

    /// Stop session (no-op, kept for compatibility)
    func stopSession() {
        // No longer needed - we capture screenshots instead
    }

    /// Add a photo (captured as screenshot from RoomCaptureView)
    func addPhoto(_ image: UIImage) {
        if let photo = savePhotoToDisk(image) {
            lock.lock()
            capturedPhotos.append(photo)
            lock.unlock()
        }
    }

    /// Get all captured photos
    var photos: [CapturedPhoto] {
        lock.lock()
        defer { lock.unlock() }
        return capturedPhotos
    }

    /// Get photo count
    var photoCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return capturedPhotos.count
    }

    /// Clear all captured photos
    func clearPhotos() {
        lock.lock()
        let oldPhotos = capturedPhotos
        capturedPhotos.removeAll()
        lock.unlock()

        // Clean up temp files
        for photo in oldPhotos {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(photo.fileName)
            try? FileManager.default.removeItem(at: tempURL)
        }
    }

    /// Copy photos to a permanent directory for a saved room
    func copyPhotos(to directory: URL) throws -> [CapturedPhoto] {
        lock.lock()
        let photos = capturedPhotos
        lock.unlock()

        // Create photos subdirectory
        let photosDir = directory.appendingPathComponent("photos")
        try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

        // Copy each photo from temp to permanent location
        for photo in photos {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(photo.fileName)
            let destURL = photosDir.appendingPathComponent(photo.fileName)
            try? FileManager.default.copyItem(at: tempURL, to: destURL)
        }

        return photos
    }

    /// Load a photo image by filename from directory
    static func loadPhoto(fileName: String, from directory: URL) -> UIImage? {
        // Try photos subdirectory first
        let photosURL = directory.appendingPathComponent("photos").appendingPathComponent(fileName)
        if let data = try? Data(contentsOf: photosURL) {
            return UIImage(data: data)
        }
        // Fallback to direct path
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Get thumbnail images for display
    func getThumbnails(maxCount: Int = 4, size: CGSize = CGSize(width: 80, height: 80)) -> [UIImage] {
        lock.lock()
        let photos = Array(capturedPhotos.prefix(maxCount))
        lock.unlock()

        var thumbnails: [UIImage] = []
        for photo in photos {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(photo.fileName)
            if let data = try? Data(contentsOf: tempURL),
               let image = UIImage(data: data) {
                // Create thumbnail
                let renderer = UIGraphicsImageRenderer(size: size)
                let thumbnail = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
                thumbnails.append(thumbnail)
            }
        }
        return thumbnails
    }

    // MARK: - Private Methods

    private func savePhotoToDisk(_ image: UIImage) -> CapturedPhoto? {
        let id = UUID()
        let fileName = "\(id.uuidString).jpg"

        // Save to temp directory for now, will be moved when room is saved
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }

        do {
            try data.write(to: tempURL)
            let photo = CapturedPhoto(id: id, timestamp: Date(), fileName: fileName)
            return photo
        } catch {
            print("Failed to save photo: \(error)")
            return nil
        }
    }
}
