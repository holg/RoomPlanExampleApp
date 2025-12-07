/*
See LICENSE folder for this sample's licensing information.

Abstract:
View controller for displaying and managing saved room scans.
*/

import UIKit

class SavedRoomsViewController: UIViewController {

    // MARK: - Properties

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var savedRooms: [SavedRoom] = []
    private var selectedRooms: Set<IndexPath> = []
    private var isSelectMode = false

    private lazy var toolbar: UIToolbar = {
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        return toolbar
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSavedRooms()
    }

    // MARK: - Setup

    private func setupUI() {
        title = L10n.SavedRooms.title.localized
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissView)
        )

        updateNavigationButtons()

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.register(SavedRoomCell.self, forCellReuseIdentifier: SavedRoomCell.reuseIdentifier)
        view.addSubview(tableView)

        view.addSubview(toolbar)
        toolbar.isHidden = true

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func updateNavigationButtons() {
        if isSelectMode {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: L10n.Common.cancel.localized,
                style: .plain,
                target: self,
                action: #selector(toggleSelectMode)
            )
        } else {
            let selectButton = UIBarButtonItem(
                title: L10n.Common.edit.localized,
                style: .plain,
                target: self,
                action: #selector(toggleSelectMode)
            )

            navigationItem.rightBarButtonItem = selectButton
            selectButton.isEnabled = !savedRooms.isEmpty
        }
    }

    private func updateToolbar() {
        let selectedCount = selectedRooms.count

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        let countLabel = UILabel()
        countLabel.text = L10n.SavedRooms.selectedCount.localized(selectedCount)
        countLabel.font = .systemFont(ofSize: 14)
        countLabel.textColor = .secondaryLabel
        let countItem = UIBarButtonItem(customView: countLabel)

        let deleteButton = UIBarButtonItem(
            title: L10n.SavedRooms.deleteSelected.localized,
            style: .plain,
            target: self,
            action: #selector(deleteSelectedRooms)
        )
        deleteButton.tintColor = .systemRed
        deleteButton.isEnabled = selectedCount > 0

        let exportButton = UIBarButtonItem(
            title: L10n.SavedRooms.exportSelected.localized,
            style: .plain,
            target: self,
            action: #selector(exportSelectedRooms)
        )
        exportButton.isEnabled = selectedCount > 0

        toolbar.setItems([deleteButton, flexSpace, countItem, flexSpace, exportButton], animated: true)
    }

    private func loadSavedRooms() {
        savedRooms = RoomStorageManager.shared.getSavedRooms()
        tableView.reloadData()
        updateNavigationButtons()
    }

    // MARK: - Actions

    @objc private func dismissView() {
        if isSelectMode {
            toggleSelectMode()
        } else {
            dismiss(animated: true)
        }
    }

    @objc private func toggleSelectMode() {
        isSelectMode.toggle()
        selectedRooms.removeAll()

        tableView.setEditing(isSelectMode, animated: true)
        toolbar.isHidden = !isSelectMode

        if isSelectMode {
            tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: toolbar.frame.height, right: 0)
        } else {
            tableView.contentInset = .zero
        }

        updateNavigationButtons()
        updateToolbar()
        tableView.reloadData()
    }

    @objc private func deleteSelectedRooms() {
        guard !selectedRooms.isEmpty else { return }

        let count = selectedRooms.count
        let alert = UIAlertController(
            title: L10n.SavedRooms.DeleteSelected.title.localized,
            message: L10n.SavedRooms.DeleteSelected.message.localized(count),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: L10n.Common.cancel.localized, style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.Common.delete.localized, style: .destructive) { [weak self] _ in
            self?.performBatchDelete()
        })

        present(alert, animated: true)
    }

    private func performBatchDelete() {
        let sortedIndexPaths = selectedRooms.sorted().reversed()

        for indexPath in sortedIndexPaths {
            let room = savedRooms[indexPath.row]
            try? RoomStorageManager.shared.deleteRoom(room)
            savedRooms.remove(at: indexPath.row)
        }

        tableView.deleteRows(at: Array(sortedIndexPaths), with: .automatic)
        selectedRooms.removeAll()

        if savedRooms.isEmpty {
            toggleSelectMode()
        } else {
            updateToolbar()
        }
    }

    @objc private func exportSelectedRooms() {
        guard !selectedRooms.isEmpty else { return }

        var itemsToExport: [Any] = []

        for indexPath in selectedRooms {
            let room = savedRooms[indexPath.row]

            let usdzURL = RoomStorageManager.shared.getUsdzURL(for: room)
            if FileManager.default.fileExists(atPath: usdzURL.path) {
                itemsToExport.append(usdzURL)
            }

            if let floorPlanImage = RoomStorageManager.shared.getFloorPlanImage(for: room) {
                itemsToExport.append(floorPlanImage)
            }
        }

        guard !itemsToExport.isEmpty else {
            showError(L10n.Export.error.localized)
            return
        }

        shareItems(itemsToExport)
    }

    private func showExportOptions(for room: SavedRoom) {
        let alert = UIAlertController(
            title: room.name,
            message: L10n.Export.chooseExport.localized,
            preferredStyle: .actionSheet
        )

        // Export USDZ (3D Model)
        let usdzURL = RoomStorageManager.shared.getUsdzURL(for: room)
        if FileManager.default.fileExists(atPath: usdzURL.path) {
            alert.addAction(UIAlertAction(title: L10n.Export.usdz.localized, style: .default) { [weak self] _ in
                self?.shareItems([usdzURL])
            })
        }

        // Export OBJ (3D Model)
        if FileManager.default.fileExists(atPath: usdzURL.path) {
            alert.addAction(UIAlertAction(title: L10n.Export.obj.localized, style: .default) { [weak self] _ in
                self?.exportAndShare(room: room, format: .obj)
            })
        }

        // Export STL (3D Print)
        if FileManager.default.fileExists(atPath: usdzURL.path) {
            alert.addAction(UIAlertAction(title: L10n.Export.stl.localized, style: .default) { [weak self] _ in
                self?.exportAndShare(room: room, format: .stl)
            })
        }

        // Export SVG (Floor Plan Vector)
        if RoomStorageManager.shared.loadFloorPlanData(for: room) != nil {
            alert.addAction(UIAlertAction(title: L10n.Export.svg.localized, style: .default) { [weak self] _ in
                self?.exportAndShare(room: room, format: .svg)
            })
        }

        // Export DXF (CAD Floor Plan)
        if RoomStorageManager.shared.loadFloorPlanData(for: room) != nil {
            alert.addAction(UIAlertAction(title: L10n.Export.dxf.localized, style: .default) { [weak self] _ in
                self?.exportAndShare(room: room, format: .dxf)
            })
        }

        // Export Floor Plan Image (PNG)
        if let floorPlanImage = RoomStorageManager.shared.getFloorPlanImage(for: room) {
            alert.addAction(UIAlertAction(title: L10n.Export.png.localized, style: .default) { [weak self] _ in
                self?.shareItems([floorPlanImage])
            })
        }

        // Export Both USDZ + Floor Plan
        if FileManager.default.fileExists(atPath: usdzURL.path),
           let floorPlanImage = RoomStorageManager.shared.getFloorPlanImage(for: room) {
            alert.addAction(UIAlertAction(title: L10n.Export.both.localized, style: .default) { [weak self] _ in
                self?.shareItems([usdzURL, floorPlanImage])
            })
        }

        // View Floor Plan
        if room.hasFloorPlan {
            alert.addAction(UIAlertAction(title: L10n.FloorPlan.view.localized, style: .default) { [weak self] _ in
                self?.showFloorPlanPreview(for: room)
            })
        }

        alert.addAction(UIAlertAction(title: L10n.Common.cancel.localized, style: .cancel))

        alert.popoverPresentationController?.sourceView = view
        present(alert, animated: true)
    }

    private enum ExportFormat {
        case obj
        case stl
        case svg
        case dxf
    }

    private func exportAndShare(room: SavedRoom, format: ExportFormat) {
        // Show loading indicator
        let loadingAlert = UIAlertController(title: L10n.Export.processing.localized, message: nil, preferredStyle: .alert)
        present(loadingAlert, animated: true)

        Task { @MainActor in
            do {
                let fileURL: URL
                switch format {
                case .obj:
                    fileURL = try RoomStorageManager.shared.exportToOBJ(for: room)
                case .stl:
                    fileURL = try RoomStorageManager.shared.exportToSTL(for: room)
                case .svg:
                    fileURL = try RoomStorageManager.shared.exportToSVG(for: room)
                case .dxf:
                    fileURL = try RoomStorageManager.shared.exportToDXF(for: room)
                }

                loadingAlert.dismiss(animated: true) {
                    self.shareItems([fileURL])
                }
            } catch {
                loadingAlert.dismiss(animated: true) {
                    self.showError(L10n.Export.error.localized)
                }
            }
        }
    }

    private func shareItems(_ items: [Any]) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = view
        present(activityVC, animated: true)
    }

    private func showFloorPlanPreview(for room: SavedRoom) {
        guard let image = RoomStorageManager.shared.getFloorPlanImage(for: room) else {
            showError(L10n.FloorPlan.notFound.localized)
            return
        }

        let previewVC = FloorPlanPreviewViewController(image: image, roomName: room.name)
        let navController = UINavigationController(rootViewController: previewVC)
        present(navController, animated: true)
    }

    private func deleteRoom(_ room: SavedRoom, at indexPath: IndexPath) {
        try? RoomStorageManager.shared.deleteRoom(room)
        savedRooms.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        updateNavigationButtons()
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: L10n.Common.error.localized, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.Common.ok.localized, style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension SavedRoomsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        savedRooms.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SavedRoomCell.reuseIdentifier, for: indexPath) as! SavedRoomCell
        cell.configure(with: savedRooms[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SavedRoomsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isSelectMode {
            selectedRooms.insert(indexPath)
            updateToolbar()
        } else {
            tableView.deselectRow(at: indexPath, animated: true)
            let room = savedRooms[indexPath.row]
            let viewerVC = RoomViewerViewController(savedRoom: room)
            let navController = UINavigationController(rootViewController: viewerVC)
            navController.modalPresentationStyle = .fullScreen
            present(navController, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isSelectMode {
            selectedRooms.remove(indexPath)
            updateToolbar()
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !isSelectMode else { return nil }

        let deleteAction = UIContextualAction(style: .destructive, title: L10n.Common.delete.localized) { [weak self] _, _, completion in
            guard let self = self else { return }
            self.deleteRoom(self.savedRooms[indexPath.row], at: indexPath)
            completion(true)
        }

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// MARK: - SavedRoomCell

class SavedRoomCell: UITableViewCell {

    static let reuseIdentifier = "SavedRoomCell"

    private let thumbnailImageView = UIImageView()
    private let nameLabel = UILabel()
    private let dateLabel = UILabel()
    private let summaryLabel = UILabel()
    private let dimensionsLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        setupCustomLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCustomLayout() {
        // Thumbnail
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.contentMode = .scaleAspectFit
        thumbnailImageView.backgroundColor = .secondarySystemBackground
        thumbnailImageView.layer.cornerRadius = 8
        thumbnailImageView.clipsToBounds = true
        contentView.addSubview(thumbnailImageView)

        // Labels stack
        let labelsStack = UIStackView()
        labelsStack.translatesAutoresizingMaskIntoConstraints = false
        labelsStack.axis = .vertical
        labelsStack.spacing = 2
        labelsStack.alignment = .leading
        contentView.addSubview(labelsStack)

        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        dateLabel.font = .systemFont(ofSize: 13)
        dateLabel.textColor = .secondaryLabel
        summaryLabel.font = .systemFont(ofSize: 13)
        summaryLabel.textColor = .secondaryLabel
        dimensionsLabel.font = .systemFont(ofSize: 12)
        dimensionsLabel.textColor = .tertiaryLabel

        labelsStack.addArrangedSubview(nameLabel)
        labelsStack.addArrangedSubview(dateLabel)
        labelsStack.addArrangedSubview(summaryLabel)
        labelsStack.addArrangedSubview(dimensionsLabel)

        NSLayoutConstraint.activate([
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbnailImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 60),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 60),
            thumbnailImageView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 8),
            thumbnailImageView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),

            labelsStack.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 12),
            labelsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            labelsStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            labelsStack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 8),
            labelsStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    func configure(with room: SavedRoom) {
        nameLabel.text = room.name
        dateLabel.text = room.formattedDate
        summaryLabel.text = room.summary
        dimensionsLabel.text = room.dimensionsSummary

        // Load floor plan thumbnail
        if let image = RoomStorageManager.shared.getFloorPlanImage(for: room) {
            thumbnailImageView.image = image
        } else {
            thumbnailImageView.image = UIImage(systemName: "square.3.layers.3d")
            thumbnailImageView.tintColor = .systemGray
        }

        dimensionsLabel.isHidden = room.dimensionsSummary.isEmpty
    }
}

// MARK: - FloorPlanPreviewViewController

class FloorPlanPreviewViewController: UIViewController {

    private let imageView = UIImageView()
    private let image: UIImage
    private let roomName: String

    init(image: UIImage, roomName: String) {
        self.image = image
        self.roomName = roomName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        title = roomName
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissView)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareImage)
        )

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = image
        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            imageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    @objc private func dismissView() {
        dismiss(animated: true)
    }

    @objc private func shareImage() {
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        activityVC.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(activityVC, animated: true)
    }
}
