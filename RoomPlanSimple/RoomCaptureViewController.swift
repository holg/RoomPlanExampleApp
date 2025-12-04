/*
See LICENSE folder for this sample's licensing information.

Abstract:
The sample app's main view controller that manages the scanning process.
*/

import UIKit
import RoomPlan

// MARK: - RoomCaptureViewController

@MainActor
class RoomCaptureViewController: UIViewController, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {

    // MARK: - IBOutlets

    @IBOutlet var exportButton: UIButton?
    @IBOutlet var doneButton: UIBarButtonItem?
    @IBOutlet var cancelButton: UIBarButtonItem?

    // MARK: - Private Properties

    private var isScanning: Bool = false
    private var roomCaptureView: RoomCaptureView!
    private var roomCaptureSessionConfig: RoomCaptureSession.Configuration = RoomCaptureSession.Configuration()
    private var finalResults: CapturedRoom?
    private var captureError: Error?

    // Statistics tracking
    private var scanStatistics = ScanStatistics()
    private var lastObjectCount = 0

    // Status UI
    private var statusLabel: UILabel?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupRoomCaptureView()
        setupStatusLabel()
        HapticFeedbackManager.shared.prepareGenerators()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }

    override func viewWillDisappear(_ flag: Bool) {
        super.viewWillDisappear(flag)
        stopSession()
        cleanupResources()

        // Clear delegates to prevent retain cycles (Issue #15)
        if isBeingDismissed || isMovingFromParent {
            roomCaptureView?.captureSession.delegate = nil
            roomCaptureView?.delegate = nil
        }
    }

    // MARK: - Setup

    private func setupRoomCaptureView() {
        roomCaptureView = RoomCaptureView(frame: view.bounds)
        roomCaptureView.captureSession.delegate = self
        roomCaptureView.delegate = self
        roomCaptureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        view.insertSubview(roomCaptureView, at: 0)
    }

    private func setupStatusLabel() {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: AppConstants.UI.statusLabelFontSize, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = AppConstants.Colors.overlayBackground
        label.layer.cornerRadius = AppConstants.UI.cornerRadius
        label.clipsToBounds = true
        label.isHidden = true

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppConstants.UI.statusLabelTopOffset),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: AppConstants.UI.statusLabelMinHeight)
        ])

        statusLabel = label
    }

    private func cleanupResources() {
        finalResults = nil
        captureError = nil
        scanStatistics = ScanStatistics()
        lastObjectCount = 0
    }

    deinit {
        #if DEBUG
        print("RoomCaptureViewController deallocated")
        #endif
    }

    // MARK: - Status Label

    private func updateStatusLabel(_ text: String, isError: Bool = false) {
        statusLabel?.text = "  \(text)  "
        statusLabel?.backgroundColor = isError
            ? AppConstants.Colors.errorBackground
            : AppConstants.Colors.overlayBackground
        statusLabel?.isHidden = false
    }

    private func hideStatusLabel() {
        UIView.animate(withDuration: AppConstants.UI.animationDuration) { [weak self] in
            self?.statusLabel?.alpha = 0
        } completion: { [weak self] _ in
            self?.statusLabel?.isHidden = true
            self?.statusLabel?.alpha = 1
        }
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

    nonisolated func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        if let error = error {
            Task { @MainActor in
                self.captureError = error
            }
        }
        return true
    }

    nonisolated func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.captureError = error
                self.showError(RoomCaptureError.processingFailed(underlying: error))
                HapticFeedbackManager.shared.scanError()
            } else {
                HapticFeedbackManager.shared.scanComplete()
            }
            self.finalResults = processedResult
            self.scanStatistics = ScanStatistics.from(processedResult)
        }
    }

    // MARK: - RoomCaptureSessionDelegate

    nonisolated func captureSession(_ session: RoomCaptureSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.captureError = error
            HapticFeedbackManager.shared.scanError()
            self.showError(RoomCaptureError.sessionFailed(underlying: error))
            self.updateStatusLabel(AppConstants.Strings.scanningFailed, isError: true)
        }
    }

    nonisolated func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        let totalObjects = room.walls.count + room.doors.count + room.windows.count + room.objects.count
        let stats = ScanStatistics.from(room)

        Task { @MainActor in
            // Haptic feedback when new objects detected
            if totalObjects > self.lastObjectCount {
                HapticFeedbackManager.shared.objectDetected()
                self.lastObjectCount = totalObjects
            }
            self.scanStatistics = stats
        }
    }

    nonisolated func captureSession(_ session: RoomCaptureSession, didStartWith configuration: RoomCaptureSession.Configuration) {
        Task { @MainActor in
            self.updateStatusLabel(AppConstants.Strings.scanningStarted)
            try? await Task.sleep(nanoseconds: UInt64(AppConstants.UI.statusLabelAutoHideDelay * 1_000_000_000))
            self.hideStatusLabel()
        }
    }

    nonisolated func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.captureError = error
                HapticFeedbackManager.shared.scanError()
                self.updateStatusLabel(AppConstants.Strings.scanEndedWithError, isError: true)
            } else {
                HapticFeedbackManager.shared.scanComplete()
                self.hideStatusLabel()
            }
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
            title: AppConstants.Strings.exportTitle,
            message: "Detected: \(scanStatistics.summary)\n\n\(AppConstants.Strings.exportMessage)",
            preferredStyle: .actionSheet
        )

        // View Floor Plan option
        alert.addAction(UIAlertAction(title: "View Floor Plan", style: .default) { [weak self] _ in
            self?.showFloorPlan()
        })

        for format in ExportFormat.allCases {
            alert.addAction(UIAlertAction(title: format.rawValue, style: .default) { _ in
                completion(format)
            })
        }

        alert.addAction(UIAlertAction(title: AppConstants.Strings.cancelButton, style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = exportButton
            popover.sourceRect = exportButton?.bounds ?? .zero
        }

        present(alert, animated: true)
    }

    private func showFloorPlan() {
        guard let room = finalResults else {
            showError(RoomCaptureError.noScanData)
            return
        }

        let floorPlanVC = FloorPlanViewController(room: room)
        let navController = UINavigationController(rootViewController: floorPlanVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    private func performExport(results: CapturedRoom, format: ExportFormat) {
        let fileName = "\(AppConstants.Export.filePrefix)_\(formatDate(Date())).\(format.fileExtension)"
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

        activityVC.completionWithItemsHandler = { [weak self] _, _, _, error in
            if let error = error {
                self?.showError(RoomCaptureError.exportFailed(underlying: error))
            }
        }

        present(activityVC, animated: true)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = AppConstants.Export.dateFormat
        return formatter.string(from: date)
    }

    // MARK: - Error Handling

    private func showError(_ error: RoomCaptureError) {
        let alert = UIAlertController(
            title: AppConstants.Strings.errorTitle,
            message: error.errorDescription,
            preferredStyle: .alert
        )

        if let suggestion = error.recoverySuggestion {
            alert.message = "\(error.errorDescription ?? "")\n\n\(suggestion)"
        }

        alert.addAction(UIAlertAction(title: AppConstants.Strings.okButton, style: .default))

        // Add retry action for export errors
        if case .exportFailed = error {
            alert.addAction(UIAlertAction(title: AppConstants.Strings.tryAgainButton, style: .default) { [weak self] _ in
                if let button = self?.exportButton {
                    self?.exportResults(button)
                }
            })
        }

        present(alert, animated: true)
    }

    // MARK: - UI State Management

    private func setActiveNavBar() {
        UIView.animate(withDuration: AppConstants.UI.animationDuration, animations: { [weak self] in
            self?.cancelButton?.tintColor = AppConstants.Colors.activeNavBarTint
            self?.doneButton?.tintColor = AppConstants.Colors.activeNavBarTint
            self?.exportButton?.alpha = 0.0
        }, completion: { [weak self] _ in
            self?.exportButton?.isHidden = true
        })
    }

    private func setCompleteNavBar() {
        exportButton?.isHidden = false
        UIView.animate(withDuration: AppConstants.UI.animationDuration) { [weak self] in
            self?.cancelButton?.tintColor = AppConstants.Colors.completeNavBarTint
            self?.doneButton?.tintColor = AppConstants.Colors.completeNavBarTint
            self?.exportButton?.alpha = 1.0
        }
    }
}
