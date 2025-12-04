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
        title = "Saved Rooms"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissView)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Delete All",
            style: .plain,
            target: self,
            action: #selector(deleteAllRooms)
        )
        navigationItem.rightBarButtonItem?.tintColor = .systemRed

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SavedRoomCell.self, forCellReuseIdentifier: SavedRoomCell.reuseIdentifier)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadSavedRooms() {
        savedRooms = RoomStorageManager.shared.getSavedRooms()
        tableView.reloadData()
        navigationItem.rightBarButtonItem?.isEnabled = !savedRooms.isEmpty
    }

    // MARK: - Actions

    @objc private func dismissView() {
        dismiss(animated: true)
    }

    @objc private func deleteAllRooms() {
        let alert = UIAlertController(
            title: "Delete All Rooms?",
            message: "This will permanently delete all \(savedRooms.count) saved room(s).",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete All", style: .destructive) { [weak self] _ in
            try? RoomStorageManager.shared.deleteAllRooms()
            self?.loadSavedRooms()
        })

        present(alert, animated: true)
    }

    private func showExportOptions(for room: SavedRoom) {
        let alert = UIAlertController(
            title: room.name,
            message: "Choose what to export",
            preferredStyle: .actionSheet
        )

        // Export 3D Model
        let usdzURL = RoomStorageManager.shared.getUsdzURL(for: room)
        if FileManager.default.fileExists(atPath: usdzURL.path) {
            alert.addAction(UIAlertAction(title: "Export 3D Model (USDZ)", style: .default) { [weak self] _ in
                self?.shareItems([usdzURL])
            })
        }

        // Export Floor Plan Image
        if let floorPlanImage = RoomStorageManager.shared.getFloorPlanImage(for: room) {
            alert.addAction(UIAlertAction(title: "Export Floor Plan Image", style: .default) { [weak self] _ in
                self?.shareItems([floorPlanImage])
            })
        }

        // Export Both
        if FileManager.default.fileExists(atPath: usdzURL.path),
           let floorPlanImage = RoomStorageManager.shared.getFloorPlanImage(for: room) {
            alert.addAction(UIAlertAction(title: "Export Both", style: .default) { [weak self] _ in
                self?.shareItems([usdzURL, floorPlanImage])
            })
        }

        // View Floor Plan
        if room.hasFloorPlan {
            alert.addAction(UIAlertAction(title: "View Floor Plan", style: .default) { [weak self] _ in
                self?.showFloorPlanPreview(for: room)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.popoverPresentationController?.sourceView = view
        present(alert, animated: true)
    }

    private func shareItems(_ items: [Any]) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = view
        present(activityVC, animated: true)
    }

    private func showFloorPlanPreview(for room: SavedRoom) {
        guard let image = RoomStorageManager.shared.getFloorPlanImage(for: room) else {
            showError("Floor plan image not found")
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
        navigationItem.rightBarButtonItem?.isEnabled = !savedRooms.isEmpty
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
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
        tableView.deselectRow(at: indexPath, animated: true)
        showExportOptions(for: savedRooms[indexPath.row])
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
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
