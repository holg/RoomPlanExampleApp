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

    // Export manager (Issue #14 refactoring)
    private lazy var exportManager = RoomExportManager(
        presentingViewController: self,
        sourceView: exportButton
    )

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupRoomCaptureView()
        setupStatusLabel()
        HapticFeedbackManager.shared.prepareGenerators()

        #if DEBUG
        // Only log on significant events, not continuously (reduces debug slowdown)
        MemoryMonitor.shared.checkpoint("RoomCaptureViewController loaded")
        #endif
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
        Task { @MainActor in
            MemoryMonitor.shared.checkpoint("RoomCaptureViewController deinit")
            _ = MemoryMonitor.shared.checkForLeaks(threshold: 20_000_000)
        }
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
        updateNavBar(isScanning: true)
    }

    private func stopSession() {
        isScanning = false
        roomCaptureView?.captureSession.stop()
        updateNavBar(isScanning: false)
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

        exportManager.showExportOptions(
            statistics: scanStatistics,
            onFloorPlan: { [weak self] in self?.showFloorPlan() },
            onSave: { [weak self] in self?.saveRoom(results) },
            onExport: { [weak self] format in
                guard let self = self else { return }
                self.exportManager.performExport(
                    results: results,
                    format: format,
                    onError: { self.showError($0) }
                )
            }
        )
    }

    // MARK: - Save Room

    private func saveRoom(_ room: CapturedRoom) {
        do {
            let savedRoom = try RoomStorageManager.shared.saveRoom(room)
            showSaveSuccess(savedRoom)
            HapticFeedbackManager.shared.scanComplete()
        } catch {
            showError(RoomCaptureError.exportFailed(underlying: error))
        }
    }

    private func showSaveSuccess(_ savedRoom: SavedRoom) {
        let alert = UIAlertController(
            title: "Room Saved",
            message: "\"\(savedRoom.name)\" saved successfully.\n\n\(savedRoom.summary)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: AppConstants.Strings.okButton, style: .default))
        present(alert, animated: true)
    }

    // MARK: - Floor Plan

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

    // MARK: - Error Handling

    private func showError(_ error: RoomCaptureError) {
        let message = [error.errorDescription, error.recoverySuggestion]
            .compactMap { $0 }
            .joined(separator: "\n\n")

        let alert = UIAlertController(title: AppConstants.Strings.errorTitle, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: AppConstants.Strings.okButton, style: .default))

        if case .exportFailed = error {
            alert.addAction(UIAlertAction(title: AppConstants.Strings.tryAgainButton, style: .default) { [weak self] _ in
                if let button = self?.exportButton { self?.exportResults(button) }
            })
        }
        present(alert, animated: true)
    }

    // MARK: - UI State Management

    private func updateNavBar(isScanning: Bool) {
        let tintColor = isScanning ? AppConstants.Colors.activeNavBarTint : AppConstants.Colors.completeNavBarTint
        exportButton?.isHidden = isScanning

        UIView.animate(withDuration: AppConstants.UI.animationDuration) { [weak self] in
            self?.cancelButton?.tintColor = tintColor
            self?.doneButton?.tintColor = tintColor
            self?.exportButton?.alpha = isScanning ? 0.0 : 1.0
        }
    }
}
