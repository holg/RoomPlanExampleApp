/*
See LICENSE folder for this sample's licensing information.

Abstract:
A view controller for the app's first screen that explains what to do.
*/

import UIKit
import RoomPlan

class OnboardingViewController: UIViewController {
    @IBOutlet var existingScanView: UIView!
    @IBOutlet weak var startScanButton: UIButton?

    private var isStartingScan = false
    private var activityIndicator: UIActivityIndicatorView?

    override func viewDidLoad() {
        super.viewDidLoad()
        checkDeviceCapability()
        setupNavigationButtons()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateSavedRoomsButton()
        // Reset state when returning to this screen
        resetScanButtonState()
    }

    private func checkDeviceCapability() {
        if !RoomCaptureSession.isSupported {
            startScanButton?.isEnabled = false
            startScanButton?.setTitle(AppConstants.Strings.deviceNotSupported, for: .disabled)
        }
    }

    private func setupNavigationButtons() {
        // Settings button on the left
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )

        // Saved rooms button on the right
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Saved",
            style: .plain,
            target: self,
            action: #selector(showSavedRooms)
        )
    }

    @objc private func showSettings() {
        let settingsVC = SettingsViewController(style: .insetGrouped)
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true)
    }

    private func updateSavedRoomsButton() {
        let count = RoomStorageManager.shared.getSavedRooms().count
        if count > 0 {
            navigationItem.rightBarButtonItem?.title = "Saved (\(count))"
            navigationItem.rightBarButtonItem?.isEnabled = true
        } else {
            navigationItem.rightBarButtonItem?.title = "Saved"
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
    }

    @objc private func showSavedRooms() {
        let savedRoomsVC = SavedRoomsViewController()
        let navController = UINavigationController(rootViewController: savedRoomsVC)
        present(navController, animated: true)
    }

    @IBAction func startScan(_ sender: UIButton) {
        // Prevent multiple taps while scan is starting
        guard !isStartingScan else { return }

        guard RoomCaptureSession.isSupported else {
            showUnsupportedDeviceAlert()
            return
        }

        guard let viewController = storyboard?.instantiateViewController(
            withIdentifier: "RoomCaptureViewNavigationController") else {
            showError(message: AppConstants.Strings.unableToStartScanning)
            return
        }

        // Show loading state
        setLoadingState(true)

        viewController.modalPresentationStyle = .fullScreen
        present(viewController, animated: true)
    }

    private func setLoadingState(_ loading: Bool) {
        isStartingScan = loading

        if loading {
            // Disable button and show spinner
            startScanButton?.isEnabled = false
            startScanButton?.alpha = 0.6

            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.color = .white
            spinner.startAnimating()
            spinner.translatesAutoresizingMaskIntoConstraints = false

            if let button = startScanButton {
                button.addSubview(spinner)
                NSLayoutConstraint.activate([
                    spinner.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -16),
                    spinner.centerYAnchor.constraint(equalTo: button.centerYAnchor)
                ])
            }
            activityIndicator = spinner
        } else {
            // Re-enable button and remove spinner
            startScanButton?.isEnabled = true
            startScanButton?.alpha = 1.0
            activityIndicator?.removeFromSuperview()
            activityIndicator = nil
        }
    }

    private func resetScanButtonState() {
        setLoadingState(false)
    }

    private func showUnsupportedDeviceAlert() {
        let alert = UIAlertController(
            title: AppConstants.Strings.unsupportedDeviceTitle,
            message: AppConstants.Strings.unsupportedDeviceMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: AppConstants.Strings.okButton, style: .default))
        present(alert, animated: true)
    }

    private func showError(message: String) {
        let alert = UIAlertController(
            title: AppConstants.Strings.errorTitle,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: AppConstants.Strings.okButton, style: .default))
        present(alert, animated: true)
    }
}
