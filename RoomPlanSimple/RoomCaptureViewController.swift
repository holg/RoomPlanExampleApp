/*
See LICENSE folder for this sample's licensing information.

Abstract:
The sample app's main view controller that manages the scanning process.
*/

import UIKit
import RoomPlan

// MARK: - Error Types (Issue #16)

enum RoomCaptureError: LocalizedError {
    case noScanData
    case exportFailed(underlying: Error)
    case sessionFailed(underlying: Error)
    case processingFailed(underlying: Error)

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
        }
    }
}

// MARK: - Export Options

enum ExportFormat: String, CaseIterable {
    case parametric = "Parametric (Furniture)"
    case mesh = "3D Mesh"

    var exportOption: CapturedRoom.USDExportOptions {
        switch self {
        case .parametric: return .parametric
        case .mesh: return .mesh
        }
    }

    var fileExtension: String { "usdz" }
}

// MARK: - RoomCaptureViewController

class RoomCaptureViewController: UIViewController, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {

    @IBOutlet var exportButton: UIButton?
    @IBOutlet var doneButton: UIBarButtonItem?
    @IBOutlet var cancelButton: UIBarButtonItem?

    private var isScanning: Bool = false
    private var roomCaptureView: RoomCaptureView!
    private var roomCaptureSessionConfig: RoomCaptureSession.Configuration = RoomCaptureSession.Configuration()
    private var finalResults: CapturedRoom?
    private var captureError: Error?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupRoomCaptureView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }

    override func viewWillDisappear(_ flag: Bool) {
        super.viewWillDisappear(flag)
        stopSession()
        cleanupResources()
    }

    // MARK: - Setup

    private func setupRoomCaptureView() {
        roomCaptureView = RoomCaptureView(frame: view.bounds)
        roomCaptureView.captureSession.delegate = self
        roomCaptureView.delegate = self
        roomCaptureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        view.insertSubview(roomCaptureView, at: 0)
    }

    private func cleanupResources() {
        finalResults = nil
        captureError = nil
    }

    // MARK: - Session Management

    private func startSession() {
        isScanning = true
        captureError = nil
        roomCaptureView?.captureSession.run(configuration: roomCaptureSessionConfig)
        setActiveNavBar()
    }

    private func stopSession() {
        isScanning = false
        roomCaptureView?.captureSession.stop()
        setCompleteNavBar()
    }

    // MARK: - RoomCaptureViewDelegate

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        if let error = error {
            captureError = error
        }
        return true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        if let error = error {
            captureError = error
            showError(RoomCaptureError.processingFailed(underlying: error))
        }
        finalResults = processedResult
    }

    // MARK: - RoomCaptureSessionDelegate

    func captureSession(_ session: RoomCaptureSession, didFailWithError error: Error) {
        captureError = error
        DispatchQueue.main.async { [weak self] in
            self?.showError(RoomCaptureError.sessionFailed(underlying: error))
        }
    }

    // MARK: - Actions

    @IBAction func doneScanning(_ sender: UIBarButtonItem) {
        if isScanning {
            stopSession()
        } else {
            cancelScanning(sender)
        }
    }

    @IBAction func cancelScanning(_ sender: UIBarButtonItem) {
        navigationController?.dismiss(animated: true)
    }

    @IBAction func exportResults(_ sender: UIButton) {
        guard let results = finalResults else {
            showError(RoomCaptureError.noScanData)
            return
        }

        showExportOptions { [weak self] format in
            self?.performExport(results: results, format: format)
        }
    }

    // MARK: - Export

    private func showExportOptions(completion: @escaping (ExportFormat) -> Void) {
        let alert = UIAlertController(
            title: "Export Format",
            message: "Choose how to export your room scan",
            preferredStyle: .actionSheet
        )

        for format in ExportFormat.allCases {
            alert.addAction(UIAlertAction(title: format.rawValue, style: .default) { _ in
                completion(format)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = exportButton
            popover.sourceRect = exportButton?.bounds ?? .zero
        }

        present(alert, animated: true)
    }

    private func performExport(results: CapturedRoom, format: ExportFormat) {
        let fileName = "Room_\(formatDate(Date())).\(format.fileExtension)"
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        // Clean up any existing file
        try? FileManager.default.removeItem(at: destinationURL)

        do {
            try results.export(to: destinationURL, exportOptions: format.exportOption)
            presentShareSheet(for: destinationURL)
        } catch {
            showError(RoomCaptureError.exportFailed(underlying: error))
        }
    }

    private func presentShareSheet(for url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.modalPresentationStyle = .popover

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = exportButton
            popover.sourceRect = exportButton?.bounds ?? .zero
        }

        activityVC.completionWithItemsHandler = { [weak self] _, completed, _, error in
            if let error = error {
                self?.showError(RoomCaptureError.exportFailed(underlying: error))
            }
        }

        present(activityVC, animated: true)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }

    // MARK: - Error Handling (Issue #16)

    private func showError(_ error: RoomCaptureError) {
        let alert = UIAlertController(
            title: "Error",
            message: error.errorDescription,
            preferredStyle: .alert
        )

        if let suggestion = error.recoverySuggestion {
            alert.message = "\(error.errorDescription ?? "")\n\n\(suggestion)"
        }

        alert.addAction(UIAlertAction(title: "OK", style: .default))

        // Add retry action for certain errors
        if case .exportFailed = error {
            alert.addAction(UIAlertAction(title: "Try Again", style: .default) { [weak self] _ in
                if let button = self?.exportButton {
                    self?.exportResults(button)
                }
            })
        }

        present(alert, animated: true)
    }

    // MARK: - UI State Management

    private func setActiveNavBar() {
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
            self?.cancelButton?.tintColor = .white
            self?.doneButton?.tintColor = .white
            self?.exportButton?.alpha = 0.0
        }, completion: { [weak self] _ in
            self?.exportButton?.isHidden = true
        })
    }

    private func setCompleteNavBar() {
        exportButton?.isHidden = false
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.cancelButton?.tintColor = .systemBlue
            self?.doneButton?.tintColor = .systemBlue
            self?.exportButton?.alpha = 1.0
        }
    }
}

