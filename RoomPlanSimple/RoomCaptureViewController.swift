/*
See LICENSE folder for this sample's licensing information.

Abstract:
The sample app's main view controller that manages the scanning process.
*/

import UIKit
import RoomPlan
import AudioToolbox

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

    // Photo capture
    private let photoCaptureManager = PhotoCaptureManager()
    private var photoButton: UIButton?
    private var photoCountLabel: UILabel?

    // WiFi signal tracking
    private let wifiSignalManager = WiFiSignalManager()
    private var wifiToggleButton: UIButton?
    private var wifiStatusLabel: UILabel?

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
        setupPhotoButton()
        setupWifiToggle()
        HapticFeedbackManager.shared.prepareGenerators()

        // Listen for WiFi permission granted notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(wifiTrackingDidEnable),
            name: .wifiTrackingDidEnable,
            object: nil
        )

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

    private func setupPhotoButton() {
        // Camera button for capturing reference photos
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 30
        button.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)

        view.addSubview(button)

        // Photo count badge
        let countLabel = UILabel()
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .systemFont(ofSize: 12, weight: .bold)
        countLabel.textColor = .white
        countLabel.backgroundColor = .systemBlue
        countLabel.textAlignment = .center
        countLabel.layer.cornerRadius = 10
        countLabel.clipsToBounds = true
        countLabel.isHidden = true

        view.addSubview(countLabel)

        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 60),
            button.heightAnchor.constraint(equalToConstant: 60),

            countLabel.topAnchor.constraint(equalTo: button.topAnchor, constant: -5),
            countLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: 5),
            countLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            countLabel.heightAnchor.constraint(equalToConstant: 20)
        ])

        photoButton = button
        photoCountLabel = countLabel
    }

    private func setupWifiToggle() {
        // WiFi toggle button (left side)
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "wifi"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 25
        button.addTarget(self, action: #selector(toggleWifi), for: .touchUpInside)

        view.addSubview(button)

        // WiFi status label (shows signal/sample count)
        let statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = .white
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        statusLabel.textAlignment = .center
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true
        statusLabel.isHidden = true

        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 50),
            button.heightAnchor.constraint(equalToConstant: 50),

            statusLabel.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 8),
            statusLabel.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            statusLabel.heightAnchor.constraint(equalToConstant: 20)
        ])

        wifiToggleButton = button
        wifiStatusLabel = statusLabel
        updateWifiButtonState()
    }

    @objc private func toggleWifi() {
        if !wifiSignalManager.isAuthorized {
            // Request permission first
            showWifiPermissionAlert()
            return
        }

        wifiSignalManager.isEnabled.toggle()
        updateWifiButtonState()

        if wifiSignalManager.isEnabled && isScanning {
            wifiSignalManager.startSampling()
        } else {
            wifiSignalManager.stopSampling()
        }

        HapticFeedbackManager.shared.objectDetected()
    }

    private func showWifiPermissionAlert() {
        let alert = UIAlertController(
            title: "WiFi Signal Tracking",
            message: "To track WiFi signal strength during scanning, this app needs location permission. This data is stored locally and not shared.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Enable", style: .default) { [weak self] _ in
            self?.wifiSignalManager.requestPermission()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }

    private func updateWifiButtonState() {
        let isOn = wifiSignalManager.isEnabled && wifiSignalManager.isAuthorized

        UIView.animate(withDuration: 0.2) { [weak self] in
            self?.wifiToggleButton?.backgroundColor = isOn
                ? UIColor.systemBlue.withAlphaComponent(0.8)
                : UIColor.black.withAlphaComponent(0.5)
            self?.wifiToggleButton?.setImage(
                UIImage(systemName: isOn ? "wifi" : "wifi.slash"),
                for: .normal
            )
        }

        wifiStatusLabel?.isHidden = !isOn
    }

    private func updateWifiStatus() {
        guard wifiSignalManager.isEnabled else { return }

        let count = wifiSignalManager.sampleCount
        if let rssi = wifiSignalManager.currentRSSI {
            wifiStatusLabel?.text = " \(rssi)dB (\(count)) "
        } else {
            wifiStatusLabel?.text = " \(count) samples "
        }
        wifiStatusLabel?.isHidden = false
    }

    @objc private func wifiTrackingDidEnable() {
        // WiFi permission was granted and tracking is now enabled
        updateWifiButtonState()
        HapticFeedbackManager.shared.scanComplete()

        // Start sampling if we're already scanning
        if isScanning {
            wifiSignalManager.startSampling()
        }
    }

    private func cleanupResources() {
        finalResults = nil
        captureError = nil
        scanStatistics = ScanStatistics()
        lastObjectCount = 0
        photoCaptureManager.clearPhotos()
        photoCaptureManager.stopSession()
        wifiSignalManager.stopSampling()
        wifiSignalManager.clearSamples()
    }

    private func updatePhotoCount() {
        let count = photoCaptureManager.photoCount
        if count > 0 {
            photoCountLabel?.text = " \(count) "
            photoCountLabel?.isHidden = false
        } else {
            photoCountLabel?.isHidden = true
        }
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
        photoCaptureManager.startSession()

        // Apply default WiFi tracking setting
        if AppSettings.shared.defaultWifiTracking && wifiSignalManager.isAuthorized {
            wifiSignalManager.isEnabled = true
            updateWifiButtonState()
        }

        // Start WiFi sampling if enabled
        if wifiSignalManager.isEnabled && wifiSignalManager.isAuthorized {
            wifiSignalManager.startSampling()
        }

        updateNavBar(isScanning: true)
    }

    private func stopSession() {
        isScanning = false
        roomCaptureView?.captureSession.stop()
        photoCaptureManager.stopSession()
        wifiSignalManager.stopSampling()
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

            // Auto-save if enabled in settings
            if AppSettings.shared.autoSaveScans && error == nil {
                self.performAutoSave(processedResult)
            }
        }
    }

    private func performAutoSave(_ room: CapturedRoom) {
        do {
            let savedRoom = try RoomStorageManager.shared.saveRoom(room, photoManager: photoCaptureManager)
            showAutoSaveConfirmation(savedRoom)
        } catch {
            // Don't show error for auto-save - just log it
            print("Auto-save failed: \(error)")
        }
    }

    private func showAutoSaveConfirmation(_ savedRoom: SavedRoom) {
        let toast = UILabel()
        toast.text = "  Saved: \(savedRoom.name)  "
        toast.font = .systemFont(ofSize: 14, weight: .medium)
        toast.textColor = .white
        toast.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
        toast.layer.cornerRadius = 16
        toast.clipsToBounds = true
        toast.textAlignment = .center
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)

        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            toast.heightAnchor.constraint(equalToConstant: 32)
        ])

        toast.alpha = 0
        UIView.animate(withDuration: 0.3, animations: {
            toast.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 2.0, options: [], animations: {
                toast.alpha = 0
            }) { _ in
                toast.removeFromSuperview()
            }
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

        // Get approximate position from room center (device is likely near edges during scan)
        let roomCenter = RoomGeometry.getRoomCenter(from: room)

        Task { @MainActor in
            // Haptic feedback when new objects detected
            if totalObjects > self.lastObjectCount {
                HapticFeedbackManager.shared.objectDetected()
                self.lastObjectCount = totalObjects
            }
            self.scanStatistics = stats

            // Update WiFi position tracking (use room center as reference)
            if let center = roomCenter {
                self.wifiSignalManager.updatePosition(center)
            }
            self.updateWifiStatus()
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

    @objc private func capturePhoto() {
        guard isScanning, let captureView = roomCaptureView else { return }

        // Visual feedback - flash effect
        photoButton?.alpha = 0.5
        HapticFeedbackManager.shared.objectDetected()

        // Play shutter sound
        AudioServicesPlaySystemSound(1108)  // Camera shutter sound

        // Create flash effect
        let flashView = UIView(frame: view.bounds)
        flashView.backgroundColor = .white
        flashView.alpha = 0
        view.addSubview(flashView)

        UIView.animate(withDuration: 0.1, animations: {
            flashView.alpha = 0.8
        }) { _ in
            UIView.animate(withDuration: 0.2, animations: {
                flashView.alpha = 0
            }) { _ in
                flashView.removeFromSuperview()
            }
        }

        // Capture screenshot of the RoomCaptureView (includes camera + AR overlay)
        let renderer = UIGraphicsImageRenderer(bounds: captureView.bounds)
        let image = renderer.image { context in
            captureView.drawHierarchy(in: captureView.bounds, afterScreenUpdates: false)
        }

        // Save the captured image
        photoCaptureManager.addPhoto(image)

        UIView.animate(withDuration: 0.2) {
            self.photoButton?.alpha = 1.0
        }

        updatePhotoCount()
        showPhotoCapturedFeedback()
    }

    private func showPhotoCapturedFeedback() {
        let feedbackLabel = UILabel()
        feedbackLabel.text = "Photo captured"
        feedbackLabel.font = .systemFont(ofSize: 14, weight: .medium)
        feedbackLabel.textColor = .white
        feedbackLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        feedbackLabel.textAlignment = .center
        feedbackLabel.layer.cornerRadius = 8
        feedbackLabel.clipsToBounds = true
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(feedbackLabel)
        NSLayoutConstraint.activate([
            feedbackLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            feedbackLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            feedbackLabel.widthAnchor.constraint(equalToConstant: 140),
            feedbackLabel.heightAnchor.constraint(equalToConstant: 32)
        ])

        UIView.animate(withDuration: 0.3, delay: 1.0, options: [], animations: {
            feedbackLabel.alpha = 0
        }) { _ in
            feedbackLabel.removeFromSuperview()
        }
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
            let savedRoom = try RoomStorageManager.shared.saveRoom(room, photoManager: photoCaptureManager)
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

        let samples = wifiSignalManager.collectedSamples
        let floorPlanVC = FloorPlanViewController(room: room, wifiSamples: samples)
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
