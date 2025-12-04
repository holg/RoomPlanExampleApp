/*
See LICENSE folder for this sample's licensing information.

Abstract:
View controller for displaying the 2D floor plan (Issues #7, #9, #10).
*/

import UIKit
import RoomPlan

class FloorPlanViewController: UIViewController {

    // MARK: - Properties

    private let floorPlanView = FloorPlanView()
    private let statsLabel = UILabel()
    private let toggleDimensionsButton = UIButton(type: .system)
    private let toggleLabelsButton = UIButton(type: .system)
    private let toggleWifiButton = UIButton(type: .system)

    private var capturedRoom: CapturedRoom?
    private var wifiSamples: [WiFiSample] = []

    // MARK: - Initialization

    init(room: CapturedRoom) {
        self.capturedRoom = room
        super.init(nibName: nil, bundle: nil)
    }

    init(room: CapturedRoom, wifiSamples: [WiFiSample]) {
        self.capturedRoom = room
        self.wifiSamples = wifiSamples
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureFloorPlan()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Clean up resources to prevent memory leaks (Issue #15)
        if isBeingDismissed || isMovingFromParent {
            capturedRoom = nil
            floorPlanView.clear()
        }
    }

    deinit {
        #if DEBUG
        print("FloorPlanViewController deallocated")
        #endif
    }

    // MARK: - Setup

    private func setupUI() {
        title = "Floor Plan"
        view.backgroundColor = .systemBackground

        // Navigation bar
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissView)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareFloorPlan)
        )

        // Floor plan view
        floorPlanView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(floorPlanView)

        // Stats label
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statsLabel.textColor = .secondaryLabel
        statsLabel.textAlignment = .center
        statsLabel.numberOfLines = 0
        view.addSubview(statsLabel)

        // Toggle buttons container
        let buttonStack = UIStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .horizontal
        buttonStack.spacing = 16
        buttonStack.distribution = .fillEqually
        view.addSubview(buttonStack)

        // Toggle dimensions button
        toggleDimensionsButton.setTitle("Dimensions: On", for: .normal)
        toggleDimensionsButton.addTarget(self, action: #selector(toggleDimensions), for: .touchUpInside)
        buttonStack.addArrangedSubview(toggleDimensionsButton)

        // Toggle labels button
        toggleLabelsButton.setTitle("Labels: On", for: .normal)
        toggleLabelsButton.addTarget(self, action: #selector(toggleLabels), for: .touchUpInside)
        buttonStack.addArrangedSubview(toggleLabelsButton)

        // Toggle WiFi heatmap button (only show if we have samples)
        if !wifiSamples.isEmpty {
            toggleWifiButton.setTitle("WiFi: On", for: .normal)
            toggleWifiButton.addTarget(self, action: #selector(toggleWifi), for: .touchUpInside)
            buttonStack.addArrangedSubview(toggleWifiButton)
        }

        // Constraints
        NSLayoutConstraint.activate([
            floorPlanView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            floorPlanView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            floorPlanView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            floorPlanView.bottomAnchor.constraint(equalTo: statsLabel.topAnchor, constant: -16),

            statsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statsLabel.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -16),

            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            buttonStack.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func configureFloorPlan() {
        guard let room = capturedRoom else { return }

        floorPlanView.configure(with: room, wifiSamples: wifiSamples)

        // Update stats with detailed measurements
        let stats = ScanStatistics.from(room)
        var statsText = stats.detailedSummary
        if !wifiSamples.isEmpty {
            statsText += "\nWiFi Samples: \(wifiSamples.count)"
        }
        statsLabel.text = statsText
    }

    // MARK: - Actions

    @objc private func dismissView() {
        dismiss(animated: true)
    }

    @objc private func toggleDimensions() {
        floorPlanView.showDimensions.toggle()
        toggleDimensionsButton.setTitle("Dimensions: \(floorPlanView.showDimensions ? "On" : "Off")", for: .normal)
    }

    @objc private func toggleLabels() {
        floorPlanView.showLabels.toggle()
        toggleLabelsButton.setTitle("Labels: \(floorPlanView.showLabels ? "On" : "Off")", for: .normal)
    }

    @objc private func toggleWifi() {
        floorPlanView.showWifiHeatmap.toggle()
        toggleWifiButton.setTitle("WiFi: \(floorPlanView.showWifiHeatmap ? "On" : "Off")", for: .normal)
    }

    @objc private func shareFloorPlan() {
        let alert = UIAlertController(
            title: "Export Floor Plan",
            message: "Choose export format",
            preferredStyle: .actionSheet
        )

        // PNG Image
        alert.addAction(UIAlertAction(title: "PNG Image", style: .default) { [weak self] _ in
            self?.exportAsPNG()
        })

        // SVG Vector
        alert.addAction(UIAlertAction(title: "SVG (Vector Graphics)", style: .default) { [weak self] _ in
            self?.exportAsSVG()
        })

        // DXF CAD
        alert.addAction(UIAlertAction(title: "DXF (AutoCAD/CAD)", style: .default) { [weak self] _ in
            self?.exportAsDXF()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }

        present(alert, animated: true)
    }

    private func exportAsPNG() {
        let renderer = UIGraphicsImageRenderer(bounds: floorPlanView.bounds)
        let image = renderer.image { context in
            floorPlanView.layer.render(in: context.cgContext)
        }

        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        activityVC.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(activityVC, animated: true)
    }

    private func exportAsSVG() {
        guard let room = capturedRoom else { return }

        let data = FloorPlanData.from(room)
        do {
            let fileURL = try FloorPlanExporter.export(
                data: data,
                format: .svg,
                includeDimensions: floorPlanView.showDimensions
            )
            shareFile(at: fileURL)
        } catch {
            showExportError(error)
        }
    }

    private func exportAsDXF() {
        guard let room = capturedRoom else { return }

        let data = FloorPlanData.from(room)
        do {
            let fileURL = try FloorPlanExporter.export(
                data: data,
                format: .dxf,
                includeDimensions: floorPlanView.showDimensions
            )
            shareFile(at: fileURL)
        } catch {
            showExportError(error)
        }
    }

    private func shareFile(at url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(activityVC, animated: true)
    }

    private func showExportError(_ error: Error) {
        let alert = UIAlertController(
            title: "Export Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Public Methods

    func updateRoom(_ room: CapturedRoom) {
        self.capturedRoom = room
        configureFloorPlan()
    }
}
