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

    private var savedRoomsButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        checkDeviceCapability()
        setupSavedRoomsButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateSavedRoomsButton()
    }

    private func checkDeviceCapability() {
        if !RoomCaptureSession.isSupported {
            startScanButton?.isEnabled = false
            startScanButton?.setTitle(AppConstants.Strings.deviceNotSupported, for: .disabled)
        }
    }

    private func setupSavedRoomsButton() {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Saved Rooms", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.addTarget(self, action: #selector(showSavedRooms), for: .touchUpInside)
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])

        savedRoomsButton = button
    }

    private func updateSavedRoomsButton() {
        let count = RoomStorageManager.shared.getSavedRooms().count
        if count > 0 {
            savedRoomsButton?.setTitle("Saved Rooms (\(count))", for: .normal)
            savedRoomsButton?.isHidden = false
        } else {
            savedRoomsButton?.isHidden = true
        }
    }

    @objc private func showSavedRooms() {
        let savedRoomsVC = SavedRoomsViewController()
        let navController = UINavigationController(rootViewController: savedRoomsVC)
        present(navController, animated: true)
    }

    @IBAction func startScan(_ sender: UIButton) {
        guard RoomCaptureSession.isSupported else {
            showUnsupportedDeviceAlert()
            return
        }

        guard let viewController = storyboard?.instantiateViewController(
            withIdentifier: "RoomCaptureViewNavigationController") else {
            showError(message: AppConstants.Strings.unableToStartScanning)
            return
        }

        viewController.modalPresentationStyle = .fullScreen
        present(viewController, animated: true)
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
