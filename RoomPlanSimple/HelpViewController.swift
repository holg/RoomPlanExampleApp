//
//  HelpViewController.swift
//  RoomPlanSimple
//
//  Comprehensive help and feature documentation
//

import UIKit

class HelpViewController: UITableViewController {

    // MARK: - Types

    private enum Section: Int, CaseIterable {
        case gettingStarted
        case icloudSetup
        case scanning
        case features
        case export
        case tips
        case troubleshooting

        var title: String {
            switch self {
            case .gettingStarted: return "Getting Started"
            case .icloudSetup: return "iCloud Setup"
            case .scanning: return "How to Scan"
            case .features: return "Features"
            case .export: return "Export Options"
            case .tips: return "Pro Tips"
            case .troubleshooting: return "Troubleshooting"
            }
        }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Help & Features"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismiss(_:))
        )

        tableView.register(HelpCell.self, forCellReuseIdentifier: "HelpCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
    }

    @objc private func dismiss(_ sender: Any) {
        dismiss(animated: true)
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }

        switch sectionType {
        case .gettingStarted: return 1
        case .icloudSetup: return 1
        case .scanning: return 1
        case .features: return 5
        case .export: return 1
        case .tips: return 5
        case .troubleshooting: return 4
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)?.title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch section {
        case .gettingStarted:
            return getGettingStartedCell(at: indexPath)
        case .icloudSetup:
            return getICloudSetupCell(at: indexPath)
        case .scanning:
            return getScanningCell(at: indexPath)
        case .features:
            return getFeaturesCell(at: indexPath)
        case .export:
            return getExportCell(at: indexPath)
        case .tips:
            return getTipsCell(at: indexPath)
        case .troubleshooting:
            return getTroubleshootingCell(at: indexPath)
        }
    }

    // MARK: - Cell Configuration

    private func getGettingStartedCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HelpCell", for: indexPath) as! HelpCell
        cell.configure(
            icon: "play.circle.fill",
            title: "Welcome to RoomPlan",
            description: """
            This app uses your device's LiDAR scanner to create accurate 3D models of rooms.

            Requirements for Scanning:
            • iPhone 12 Pro or later
            • iPad Pro (2020 or later)
            • iOS 16.0 or later

            Note: You can view saved rooms on any device, even without LiDAR! Use iCloud to sync rooms across devices.
            """
        )
        return cell
    }

    private func getICloudSetupCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HelpCell", for: indexPath) as! HelpCell
        cell.configure(
            icon: "icloud.circle.fill",
            title: "Sync Saved Rooms with iCloud",
            description: """
            Enable iCloud sync to access your saved rooms on all your devices - even those without LiDAR!

            How to Enable:
            1. Go to Settings (gear icon)
            2. Toggle "iCloud Sync" ON
            3. Your rooms will automatically sync

            Requirements:
            • Signed in to iCloud in iOS Settings
            • iCloud Drive enabled
            • Internet connection

            Benefits:
            • Access scans from non-LiDAR devices
            • Automatic backup of your scans
            • Share rooms across iPhone and iPad
            • View 3D models anywhere
            """
        )
        return cell
    }

    private func getScanningCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HelpCell", for: indexPath) as! HelpCell
        cell.configure(
            icon: "camera.viewfinder",
            title: "How to Scan a Room",
            description: """
            1. Tap "Start New Scan" on the home screen
            2. Point your device at a corner of the room
            3. Slowly move along each wall, keeping the wall in view
            4. Scan all walls, windows, doors, and openings
            5. Include furniture and objects you want to capture
            6. Watch the bottom preview to see your progress
            7. Tap "Done" when the room looks complete

            Tips for Best Results:
            • Keep your device upright
            • Move slowly and steadily
            • Ensure good lighting
            • Scan each wall at least once
            • Get close to details you want captured
            """
        )
        return cell
    }

    private func getFeaturesCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HelpCell", for: indexPath) as! HelpCell

        let features = [
            ("cube.transparent.fill", "3D Room Capture",
             "Create accurate 3D models with LiDAR technology. The app automatically detects walls, windows, doors, and furniture."),

            ("wifi", "WiFi Heatmap",
             "Enable WiFi tracking during scanning to create a signal strength heatmap. Perfect for planning router placement. Requires location permission."),

            ("camera.fill", "Photo Capture",
             "Take photos during scanning to document the space. Photos are saved with your scan and shown on the floor plan."),

            ("square.and.arrow.up", "Multiple Export Formats",
             "Export your scans in various formats:\n• USDZ - 3D model for AR/Preview\n• OBJ - 3D model for CAD software\n• STL - 3D model for 3D printing\n• DXF - Floor plan for CAD\n• SVG - Floor plan vector\n• PNG - Floor plan image"),

            ("icloud.fill", "iCloud Sync (Optional)",
             "Enable in Settings to sync your scans across all your devices. When enabled, scans are stored in iCloud Drive and available on all devices signed in with your Apple ID.")
        ]

        let feature = features[indexPath.row]
        cell.configure(icon: feature.0, title: feature.1, description: feature.2)
        return cell
    }

    private func getExportCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HelpCell", for: indexPath) as! HelpCell
        cell.configure(
            icon: "square.and.arrow.up.fill",
            title: "Export Your Scans",
            description: """
            After completing a scan, you can export it in multiple formats:

            3D Model Formats:
            • USDZ - Best for Apple devices, AR Quick Look
            • OBJ - Universal 3D format for modeling software
            • STL - For 3D printing applications

            Floor Plan Formats:
            • PNG - Image for quick sharing
            • SVG - Vector format for graphic design
            • DXF - CAD format for architects/designers

            To export:
            1. Complete your scan or open a saved room
            2. Tap the export button
            3. Choose your format
            4. Share via AirDrop, email, or save to Files

            All measurements are included in the exported files.
            """
        )
        return cell
    }

    private func getTipsCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HelpCell", for: indexPath) as! HelpCell

        let tips = [
            ("lightbulb.fill", "Lighting is Key",
             "Scan in good lighting conditions. Natural daylight or bright indoor lighting works best. Avoid very dark or very bright areas."),

            ("tortoise.fill", "Slow and Steady",
             "Move slowly and smoothly. Rapid movements or shaking can affect scan quality. Take your time for best results."),

            ("arrow.triangle.2.circlepath", "Scan Multiple Times",
             "If you're not happy with the first scan, try again! Each room is different and sometimes it takes a few attempts to get it perfect."),

            ("square.stack.3d.up.fill", "Save Everything",
             "Enable auto-save in Settings so you never lose a scan. You can always delete unwanted scans later."),

            ("chart.xyaxis.line", "Check Measurements",
             "After scanning, tap to view floor plan and verify measurements look correct. The app shows dimensions in meters or feet.")
        ]

        let tip = tips[indexPath.row]
        cell.configure(icon: tip.0, title: tip.1, description: tip.2)
        return cell
    }

    private func getTroubleshootingCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HelpCell", for: indexPath) as! HelpCell

        let issues = [
            ("exclamationmark.triangle.fill", "Scan Not Starting",
             "Ensure you have a LiDAR-enabled device (iPhone 12 Pro or later, iPad Pro 2020+). Check that camera permissions are granted in Settings → Privacy → Camera."),

            ("camera.metering.partial", "Poor Scan Quality",
             "Try these fixes:\n• Improve room lighting\n• Move more slowly\n• Get closer to walls and objects\n• Scan each wall multiple times\n• Clear obstructions from camera lens"),

            ("internaldrive.fill", "Scans Disappeared",
             "If scans are missing after updating the app:\n• Check Settings → iCloud Sync\n• Scans are now stored in Application Support\n• Old scans may be in Documents folder"),

            ("wifi.slash", "WiFi Heatmap Not Working",
             "WiFi tracking requires:\n• Location permission (Settings → Privacy → Location)\n• WiFi enabled on device\n• Connected to a WiFi network\n• Toggle ON in scan screen or Settings")
        ]

        let issue = issues[indexPath.row]
        cell.configure(icon: issue.0, title: issue.1, description: issue.2)
        return cell
    }
}

// MARK: - HelpCell

private class HelpCell: UITableViewCell {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        selectionStyle = .none

        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        descriptionLabel.font = .systemFont(ofSize: 15)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    func configure(icon: String, title: String, description: String) {
        iconView.image = UIImage(systemName: icon)
        titleLabel.text = title
        descriptionLabel.text = description
    }
}
