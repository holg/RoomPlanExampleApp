//
//  HomeViewController.swift
//  RoomPlanSimple
//
//  Modern home screen with quick actions and recent scans
//

import UIKit
import RoomPlan

@MainActor
class HomeViewController: UIViewController {

    // MARK: - UI Components

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let headerLabel = UILabel()
    private let newScanButton = UIButton(type: .system)
    private let savedRoomsButton = UIButton(type: .system)
    private let helpButton = UIButton(type: .system)

    private let recentScansLabel = UILabel()
    private let recentScansStack = UIStackView()
    private let emptyStateLabel = UILabel()

    private let featuresLabel = UILabel()
    private let featuresStack = UIStackView()

    private var isStartingScan = false
    private var activityIndicator: UIActivityIndicatorView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkDeviceCapability()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateRecentScans()

        #if DEBUG
        // Print storage debug info to help diagnose iCloud issues
        RoomStorageManager.shared.debugStorageInfo()
        #endif
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = L10n.Home.title.localized

        setupNavigationBar()
        setupScrollView()
        setupHeader()
        setupActionButtons()
        setupRecentScans()
        setupFeatures()
    }

    private func setupNavigationBar() {
        // Settings button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 32
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

    private func setupHeader() {
        headerLabel.text = L10n.Home.header.localized
        headerLabel.font = .systemFont(ofSize: 28, weight: .bold)
        headerLabel.textAlignment = .center
        contentStack.addArrangedSubview(headerLabel)
    }

    private func setupActionButtons() {
        let buttonsStack = UIStackView()
        buttonsStack.axis = .vertical
        buttonsStack.spacing = 16
        buttonsStack.distribution = .fillEqually

        // New Scan Button
        configureButton(
            newScanButton,
            title: L10n.Home.NewScan.title.localized,
            subtitle: L10n.Home.NewScan.subtitle.localized,
            icon: "cube.transparent.fill",
            backgroundColor: .systemBlue
        )
        newScanButton.addTarget(self, action: #selector(startScan), for: .touchUpInside)

        // Saved Rooms Button
        configureButton(
            savedRoomsButton,
            title: L10n.Home.SavedRooms.title.localized,
            subtitle: L10n.Home.SavedRooms.subtitle.localized,
            icon: "square.stack.3d.up.fill",
            backgroundColor: .systemGreen
        )
        savedRoomsButton.addTarget(self, action: #selector(showSavedRooms), for: .touchUpInside)

        // Help Button
        configureButton(
            helpButton,
            title: L10n.Home.Help.title.localized,
            subtitle: L10n.Home.Help.subtitle.localized,
            icon: "questionmark.circle.fill",
            backgroundColor: .systemOrange
        )
        helpButton.addTarget(self, action: #selector(showHelp), for: .touchUpInside)

        buttonsStack.addArrangedSubview(newScanButton)
        buttonsStack.addArrangedSubview(savedRoomsButton)
        buttonsStack.addArrangedSubview(helpButton)

        contentStack.addArrangedSubview(buttonsStack)
    }

    private func configureButton(_ button: UIButton, title: String, subtitle: String, icon: String, backgroundColor: UIColor) {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = backgroundColor
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)

        var titleAttr = AttributedString(title)
        titleAttr.font = .systemFont(ofSize: 20, weight: .semibold)
        config.attributedTitle = titleAttr

        var subtitleAttr = AttributedString(subtitle)
        subtitleAttr.font = .systemFont(ofSize: 14)
        config.attributedSubtitle = subtitleAttr

        config.image = UIImage(systemName: icon)
        config.imagePlacement = .leading
        config.imagePadding = 12
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 28)

        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 80).isActive = true
    }

    private func setupRecentScans() {
        recentScansLabel.text = L10n.Home.recentScans.localized
        recentScansLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        contentStack.addArrangedSubview(recentScansLabel)

        recentScansStack.axis = .vertical
        recentScansStack.spacing = 12
        contentStack.addArrangedSubview(recentScansStack)

        emptyStateLabel.text = L10n.Home.emptyState.localized
        emptyStateLabel.font = .systemFont(ofSize: 16)
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.isHidden = true
        contentStack.addArrangedSubview(emptyStateLabel)
    }

    private func setupFeatures() {
        featuresLabel.text = L10n.Home.features.localized
        featuresLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        contentStack.addArrangedSubview(featuresLabel)

        featuresStack.axis = .vertical
        featuresStack.spacing = 12

        let features = [
            ("cube.transparent", L10n.Feature.capture3DTitle.localized, L10n.Feature.capture3DDescription.localized),
            ("wifi", L10n.Feature.wifiHeatmapTitle.localized, L10n.Feature.wifiHeatmapDescription.localized),
            ("camera.fill", L10n.Feature.photoCaptureTitle.localized, L10n.Feature.photoCaptureDescription.localized),
            ("square.and.arrow.up", L10n.Feature.exportTitle.localized, L10n.Feature.exportDescription.localized),
            ("icloud.fill", L10n.Feature.icloudTitle.localized, L10n.Feature.icloudDescription.localized)
        ]

        for (icon, title, description) in features {
            let featureView = createFeatureView(icon: icon, title: title, description: description)
            featuresStack.addArrangedSubview(featureView)
        }

        contentStack.addArrangedSubview(featuresStack)
    }

    private func createFeatureView(icon: String, title: String, description: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let descLabel = UILabel()
        descLabel.text = description
        descLabel.font = .systemFont(ofSize: 14)
        descLabel.textColor = .secondaryLabel
        descLabel.numberOfLines = 0
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconView)
        container.addSubview(titleLabel)
        container.addSubview(descLabel)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),

            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        return container
    }

    // MARK: - Recent Scans

    private func updateRecentScans() {
        // Clear existing
        recentScansStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let savedRooms = RoomStorageManager.shared.getSavedRooms()
        let recentRooms = Array(savedRooms.prefix(3))

        if recentRooms.isEmpty {
            recentScansLabel.isHidden = true
            recentScansStack.isHidden = true
            emptyStateLabel.isHidden = false
            savedRoomsButton.isEnabled = false
        } else {
            recentScansLabel.isHidden = false
            recentScansStack.isHidden = false
            emptyStateLabel.isHidden = true
            savedRoomsButton.isEnabled = true

            for room in recentRooms {
                let roomCard = createRoomCard(for: room)
                recentScansStack.addArrangedSubview(roomCard)
            }
        }

        // Update saved button title
        if savedRooms.count > 0 {
            var config = savedRoomsButton.configuration
            let roomWord = savedRooms.count == 1 ? L10n.Home.SavedRooms.room.localized : L10n.Home.SavedRooms.rooms.localized
            config?.attributedSubtitle = AttributedString(L10n.Home.SavedRooms.count.localized(savedRooms.count, roomWord))
            savedRoomsButton.configuration = config
        }
    }

    private func createRoomCard(for room: SavedRoom) -> UIView {
        let container = UIView()
        container.backgroundColor = .tertiarySystemBackground
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)

        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)

        var titleAttr = AttributedString(room.name)
        titleAttr.font = .systemFont(ofSize: 16, weight: .medium)
        config.attributedTitle = titleAttr

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        var subtitleAttr = AttributedString(formatter.string(from: room.date))
        subtitleAttr.font = .systemFont(ofSize: 14)
        subtitleAttr.foregroundColor = .secondaryLabel
        config.attributedSubtitle = subtitleAttr

        config.image = UIImage(systemName: "cube.fill")
        config.imagePlacement = .leading
        config.imagePadding = 8

        button.configuration = config
        button.tag = room.name.hashValue
        button.addTarget(self, action: #selector(openRecentRoom), for: .touchUpInside)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 60),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    // MARK: - Device Check

    private func checkDeviceCapability() {
        if !RoomCaptureSession.isSupported {
            newScanButton.isEnabled = false
            newScanButton.alpha = 0.5
            var config = newScanButton.configuration
            config?.attributedSubtitle = AttributedString(L10n.Home.NewScan.noLidar.localized)
            newScanButton.configuration = config

            #if DEBUG
            print("⚠️  LiDAR not available - Scanning disabled, but viewing saved rooms is still available")
            #endif
        } else {
            #if DEBUG
            print("✅ LiDAR available - Full scanning functionality enabled")
            #endif
        }
    }

    // MARK: - Actions

    @objc private func startScan() {
        guard !isStartingScan else { return }

        guard RoomCaptureSession.isSupported else {
            showUnsupportedDeviceAlert()
            return
        }

        // Load from Main.storyboard since HomeViewController is created programmatically
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let viewController = storyboard.instantiateViewController(
            withIdentifier: "RoomCaptureViewNavigationController") as? UINavigationController else {
            showError(message: "Unable to start scanning - RoomCaptureViewController not found in storyboard")
            #if DEBUG
            print("❌ Failed to load RoomCaptureViewNavigationController from Main.storyboard")
            #endif
            return
        }

        viewController.modalPresentationStyle = .fullScreen
        present(viewController, animated: true)
    }

    @objc private func showSavedRooms() {
        let savedRoomsVC = SavedRoomsViewController()
        let navController = UINavigationController(rootViewController: savedRoomsVC)
        present(navController, animated: true)
    }

    @objc private func showSettings() {
        let settingsVC = SettingsViewController(style: .insetGrouped)
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true)
    }

    @objc private func showHelp() {
        let helpVC = HelpViewController()
        let navController = UINavigationController(rootViewController: helpVC)
        present(navController, animated: true)
    }

    @objc private func openRecentRoom(_ sender: UIButton) {
        showSavedRooms()
    }

    // MARK: - Alerts

    private func showUnsupportedDeviceAlert() {
        let alert = UIAlertController(
            title: L10n.Alert.unsupportedDeviceTitle.localized,
            message: L10n.Alert.unsupportedDeviceMessage.localized,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.Common.ok.localized, style: .default))
        present(alert, animated: true)
    }

    private func showError(message: String) {
        let alert = UIAlertController(
            title: L10n.Common.error.localized,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.Common.ok.localized, style: .default))
        present(alert, animated: true)
    }
}
