/*
See LICENSE folder for this sample's licensing information.

Abstract:
Manages export functionality for captured room data (Issue #14 refactoring).
*/

import UIKit
import RoomPlan

/// Handles room export operations and share sheet presentation
@MainActor
final class RoomExportManager {

    // MARK: - Properties

    private weak var presentingViewController: UIViewController?
    private weak var sourceView: UIView?

    // MARK: - Initialization

    init(presentingViewController: UIViewController, sourceView: UIView?) {
        self.presentingViewController = presentingViewController
        self.sourceView = sourceView
    }

    // MARK: - Export Methods

    /// Shows export options action sheet
    func showExportOptions(
        statistics: ScanStatistics,
        onFloorPlan: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onExport: @escaping (ExportFormat) -> Void
    ) {
        let alert = UIAlertController(
            title: AppConstants.Strings.exportTitle,
            message: "Detected: \(statistics.summary)\n\n\(AppConstants.Strings.exportMessage)",
            preferredStyle: .actionSheet
        )

        // Save Room option
        alert.addAction(UIAlertAction(title: "Save Room", style: .default) { _ in
            onSave()
        })

        // View Floor Plan option
        alert.addAction(UIAlertAction(title: "View Floor Plan", style: .default) { _ in
            onFloorPlan()
        })

        for format in ExportFormat.allCases {
            alert.addAction(UIAlertAction(title: format.rawValue, style: .default) { _ in
                onExport(format)
            })
        }

        alert.addAction(UIAlertAction(title: AppConstants.Strings.cancelButton, style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView?.bounds ?? .zero
        }

        presentingViewController?.present(alert, animated: true)
    }

    /// Performs export of captured room to file
    func performExport(
        results: CapturedRoom,
        format: ExportFormat,
        onError: @escaping (RoomCaptureError) -> Void
    ) {
        let fileName = "\(AppConstants.Export.filePrefix)_\(formatDate(Date())).\(format.fileExtension)"
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        // Clean up any existing file
        try? FileManager.default.removeItem(at: destinationURL)

        do {
            try results.export(to: destinationURL, exportOptions: format.exportOption)
            presentShareSheet(for: destinationURL, onError: onError)
        } catch {
            onError(RoomCaptureError.exportFailed(underlying: error))
        }
    }

    // MARK: - Private Methods

    private func presentShareSheet(for url: URL, onError: @escaping (RoomCaptureError) -> Void) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.modalPresentationStyle = .popover

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView?.bounds ?? .zero
        }

        activityVC.completionWithItemsHandler = { _, _, _, error in
            if let error = error {
                onError(RoomCaptureError.exportFailed(underlying: error))
            }
        }

        presentingViewController?.present(activityVC, animated: true)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = AppConstants.Export.dateFormat
        return formatter.string(from: date)
    }
}
