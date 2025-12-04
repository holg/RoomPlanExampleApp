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

    override func viewDidLoad() {
        super.viewDidLoad()
        checkDeviceCapability()
    }

    private func checkDeviceCapability() {
        if !RoomCaptureSession.isSupported {
            startScanButton?.isEnabled = false
            startScanButton?.setTitle("Device Not Supported", for: .disabled)
        }
    }

    @IBAction func startScan(_ sender: UIButton) {
        guard RoomCaptureSession.isSupported else {
            showUnsupportedDeviceAlert()
            return
        }

        guard let viewController = storyboard?.instantiateViewController(
            withIdentifier: "RoomCaptureViewNavigationController") else {
            showError(message: "Unable to start scanning. Please restart the app.")
            return
        }

        viewController.modalPresentationStyle = .fullScreen
        present(viewController, animated: true)
    }

    private func showUnsupportedDeviceAlert() {
        let alert = UIAlertController(
            title: "Unsupported Device",
            message: "This device doesn't have a LiDAR scanner. RoomPlan requires iPhone 12 Pro or later, or iPad Pro with LiDAR.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showError(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
