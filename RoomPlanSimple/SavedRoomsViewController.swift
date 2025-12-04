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
        let url = RoomStorageManager.shared.getUsdzURL(for: room)

        guard FileManager.default.fileExists(atPath: url.path) else {
            showError("Room file not found")
            return
        }

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = view

        present(activityVC, animated: true)
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

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with room: SavedRoom) {
        textLabel?.text = room.name
        detailTextLabel?.text = "\(room.formattedDate) - \(room.summary)"
        detailTextLabel?.textColor = .secondaryLabel
    }
}
