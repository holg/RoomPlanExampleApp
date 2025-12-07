//
//  RoomViewerViewController.swift
//  RoomPlanSimple
//
//  Comprehensive viewer for saved rooms - floor plan, 3D model, photos, WiFi data
//

import UIKit
import RoomPlan
import SceneKit

@MainActor
class RoomViewerViewController: UIViewController {

    // MARK: - Types

    private enum ViewMode {
        case floorPlan
        case model3D
        case photos
        case wifiHeatmap
    }

    // MARK: - Properties

    private let savedRoom: SavedRoom
    private var wifiSamples: [WiFiSample] = []
    private var currentMode: ViewMode = .floorPlan
    private var floorPlanImage: UIImage?

    // UI Components
    private let segmentedControl = UISegmentedControl(items: [
        L10n.Viewer.Mode.floorPlan.localized,
        L10n.Viewer.Mode.model3D.localized,
        L10n.Viewer.Mode.photos.localized,
        L10n.Viewer.Mode.wifi.localized
    ])
    private let containerView = UIView()


    // MARK: - Initialization

    init(savedRoom: SavedRoom) {
        self.savedRoom = savedRoom
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadRoomData()
    }

    // MARK: - Setup

    private func setupUI() {
        title = savedRoom.name
        view.backgroundColor = .systemBackground

        // Navigation buttons
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissView)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareRoom)
        )

        // Segmented control
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)

        // Container view
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            containerView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadRoomData() {
        // Load WiFi samples if available
        self.wifiSamples = RoomStorageManager.shared.loadWiFiSamples(for: savedRoom)

        // Load floor plan image
        self.floorPlanImage = RoomStorageManager.shared.getFloorPlanImage(for: savedRoom)

        // Show floor plan by default
        showFloorPlan()
    }

    // MARK: - Mode Switching

    @objc private func modeChanged() {
        // Remove current view
        children.forEach { $0.removeFromParent(); $0.view.removeFromSuperview() }

        switch segmentedControl.selectedSegmentIndex {
        case 0:
            currentMode = .floorPlan
            showFloorPlan()
        case 1:
            currentMode = .model3D
            show3DModel()
        case 2:
            currentMode = .photos
            showPhotos()
        case 3:
            currentMode = .wifiHeatmap
            showWiFiHeatmap()
        default:
            break
        }
    }

    private func showFloorPlan() {
        guard let image = floorPlanImage else {
            showMessage(L10n.Viewer.noFloorPlan.localized)
            return
        }

        // Create an interactive image view with pinch/pan gestures
        let scrollView = UIScrollView(frame: containerView.bounds)
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 4.0
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = scrollView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.tag = 100 // Tag for zoom reference

        scrollView.addSubview(imageView)
        containerView.addSubview(scrollView)

        // Add pinch gesture hint
        let hintLabel = UILabel()
        hintLabel.text = L10n.Viewer.floorPlanHint.localized
        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = .secondaryLabel
        hintLabel.textAlignment = .center
        hintLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            hintLabel.bottomAnchor.constraint(equalTo: scrollView.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            hintLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            hintLabel.widthAnchor.constraint(lessThanOrEqualTo: scrollView.widthAnchor, constant: -32)
        ])
    }

    private func show3DModel() {

        let sceneView = SCNView(frame: containerView.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.backgroundColor = .systemBackground
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.antialiasingMode = .multisampling4X

        // Create a scene from the room (convert USDZ)
        let usdzURL = RoomStorageManager.shared.getUsdzURL(for: savedRoom)
        if let scene = try? SCNScene(url: usdzURL, options: nil) {
            sceneView.scene = scene

            // Add a camera if none exists
            if scene.rootNode.childNodes(passingTest: { node, _ in node.camera != nil }).isEmpty {
                let cameraNode = SCNNode()
                cameraNode.camera = SCNCamera()
                cameraNode.position = SCNVector3(x: 0, y: 2, z: 5)
                cameraNode.look(at: SCNVector3(x: 0, y: 0, z: 0))
                scene.rootNode.addChildNode(cameraNode)
            }
        }

        let vc = UIViewController()
        vc.view = sceneView
        addChild(vc)
        containerView.addSubview(vc.view)
        vc.didMove(toParent: self)


        // Add instructions overlay
        let instructionsLabel = UILabel()
        instructionsLabel.text = L10n.Viewer.model3DHint.localized
        instructionsLabel.font = .systemFont(ofSize: 12)
        instructionsLabel.textColor = .secondaryLabel
        instructionsLabel.textAlignment = .center
        instructionsLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false
        sceneView.addSubview(instructionsLabel)

        NSLayoutConstraint.activate([
            instructionsLabel.bottomAnchor.constraint(equalTo: sceneView.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            instructionsLabel.centerXAnchor.constraint(equalTo: sceneView.centerXAnchor),
            instructionsLabel.widthAnchor.constraint(lessThanOrEqualTo: sceneView.widthAnchor, constant: -32)
        ])
    }

    private func showPhotos() {
        // TODO: Implement photos gallery
        let label = UILabel()
        label.text = L10n.Viewer.photosPlaceholder.localized
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.frame = containerView.bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        vc.view.addSubview(label)

        addChild(vc)
        containerView.addSubview(vc.view)
        vc.didMove(toParent: self)

    }

    private func showWiFiHeatmap() {
        if wifiSamples.isEmpty {
            showMessage(L10n.Viewer.noWifiData.localized)
        } else {
            showMessage(L10n.Viewer.wifiSamplesCount.localized(wifiSamples.count))
        }
    }

    private func showMessage(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.frame = containerView.bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        vc.view.addSubview(label)

        addChild(vc)
        containerView.addSubview(vc.view)
        vc.view.frame = containerView.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        vc.didMove(toParent: self)
    }

    // MARK: - Actions

    @objc private func dismissView() {
        dismiss(animated: true)
    }

    @objc private func shareRoom() {
        let alert = UIAlertController(
            title: L10n.Export.title.localized,
            message: L10n.Export.chooseExport.localized,
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: L10n.Export.usdz.localized, style: .default) { [weak self] _ in
            self?.shareUSDZ()
        })

        alert.addAction(UIAlertAction(title: L10n.Export.obj.localized, style: .default) { [weak self] _ in
            self?.shareOBJ()
        })

        alert.addAction(UIAlertAction(title: L10n.Export.stl.localized, style: .default) { [weak self] _ in
            self?.shareSTL()
        })

        alert.addAction(UIAlertAction(title: L10n.Export.dxf.localized, style: .default) { [weak self] _ in
            self?.shareFloorPlanDXF()
        })

        alert.addAction(UIAlertAction(title: L10n.Export.svg.localized, style: .default) { [weak self] _ in
            self?.shareFloorPlanSVG()
        })

        alert.addAction(UIAlertAction(title: L10n.Export.png.localized, style: .default) { [weak self] _ in
            self?.shareFloorPlanPNG()
        })

        alert.addAction(UIAlertAction(title: L10n.Common.cancel.localized, style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }

        present(alert, animated: true)
    }

    private func shareUSDZ() {
        let url = RoomStorageManager.shared.getUsdzURL(for: savedRoom)
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(activityVC, animated: true)
    }

    private func shareOBJ() {
        // TODO: Implementation for sharing OBJ format
        showMessage(L10n.Export.error.localized)
    }

    private func shareSTL() {
        // TODO: Implementation for sharing STL format
        showMessage(L10n.Export.error.localized)
    }

    private func shareFloorPlanDXF() {
        // TODO: Implementation for sharing floor plan DXF
        showMessage(L10n.Export.error.localized)
    }

    private func shareFloorPlanSVG() {
        // TODO: Implementation for sharing floor plan SVG
        showMessage(L10n.Export.error.localized)
    }

    private func shareFloorPlanPNG() {
        // TODO: Implementation for sharing floor plan PNG
        guard let image = floorPlanImage else {
            showMessage(L10n.Viewer.noFloorPlan.localized)
            return
        }
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        activityVC.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(activityVC, animated: true)
    }
}

// MARK: - UIScrollViewDelegate

extension RoomViewerViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollView.viewWithTag(100) // The imageView
    }
}
