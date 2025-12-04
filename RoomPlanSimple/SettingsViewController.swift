/*
See LICENSE folder for this sample's licensing information.

Abstract:
Settings view controller for app preferences.
*/

import UIKit

class SettingsViewController: UITableViewController {

    // MARK: - Types

    private enum Section: Int, CaseIterable {
        case scanning
        case saving
        case about

        var title: String {
            switch self {
            case .scanning: return "Scanning"
            case .saving: return "Saving"
            case .about: return "About"
            }
        }
    }

    private enum ScanningRow: Int, CaseIterable {
        case defaultWifiTracking
    }

    private enum SavingRow: Int, CaseIterable {
        case autoSave
    }

    private enum AboutRow: Int, CaseIterable {
        case version
        case resetSettings
    }

    // MARK: - Properties

    private let settings = AppSettings.shared

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissSettings)
        )

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(SwitchCell.self, forCellReuseIdentifier: "SwitchCell")
    }

    // MARK: - Actions

    @objc private func dismissSettings() {
        dismiss(animated: true)
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        switch sectionType {
        case .scanning: return ScanningRow.allCases.count
        case .saving: return SavingRow.allCases.count
        case .about: return AboutRow.allCases.count
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
        case .scanning:
            guard let row = ScanningRow(rawValue: indexPath.row) else { return UITableViewCell() }
            return configureScanningCell(for: row, at: indexPath)

        case .saving:
            guard let row = SavingRow(rawValue: indexPath.row) else { return UITableViewCell() }
            return configureSavingCell(for: row, at: indexPath)

        case .about:
            guard let row = AboutRow(rawValue: indexPath.row) else { return UITableViewCell() }
            return configureAboutCell(for: row, at: indexPath)
        }
    }

    // MARK: - Cell Configuration

    private func configureScanningCell(for row: ScanningRow, at indexPath: IndexPath) -> UITableViewCell {
        switch row {
        case .defaultWifiTracking:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchCell
            cell.configure(
                title: "WiFi Tracking by Default",
                subtitle: "Automatically enable WiFi signal tracking when starting a scan",
                isOn: settings.defaultWifiTracking
            ) { [weak self] isOn in
                self?.settings.defaultWifiTracking = isOn
            }
            return cell
        }
    }

    private func configureSavingCell(for row: SavingRow, at indexPath: IndexPath) -> UITableViewCell {
        switch row {
        case .autoSave:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchCell
            cell.configure(
                title: "Auto-Save Scans",
                subtitle: "Automatically save completed scans to your library",
                isOn: settings.autoSaveScans
            ) { [weak self] isOn in
                self?.settings.autoSaveScans = isOn
            }
            return cell
        }
    }

    private func configureAboutCell(for row: AboutRow, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        var content = cell.defaultContentConfiguration()

        switch row {
        case .version:
            content.text = "Version"
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            content.secondaryText = "\(version) (\(build))"
            cell.selectionStyle = .none

        case .resetSettings:
            content.text = "Reset to Defaults"
            content.textProperties.color = .systemRed
            cell.selectionStyle = .default
        }

        cell.contentConfiguration = content
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let section = Section(rawValue: indexPath.section) else { return }

        if section == .about, let row = AboutRow(rawValue: indexPath.row), row == .resetSettings {
            confirmResetSettings()
        }
    }

    private func confirmResetSettings() {
        let alert = UIAlertController(
            title: "Reset Settings",
            message: "Are you sure you want to reset all settings to their defaults?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { [weak self] _ in
            self?.settings.resetToDefaults()
            self?.tableView.reloadData()
        })

        present(alert, animated: true)
    }
}

// MARK: - SwitchCell

private class SwitchCell: UITableViewCell {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let toggleSwitch = UISwitch()
    private var onToggle: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        selectionStyle = .none

        titleLabel.font = .systemFont(ofSize: 17)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        toggleSwitch.addTarget(self, action: #selector(switchToggled), for: .valueChanged)
        toggleSwitch.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(toggleSwitch)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggleSwitch.leadingAnchor, constant: -12),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: toggleSwitch.leadingAnchor, constant: -12),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            toggleSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            toggleSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    func configure(title: String, subtitle: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        toggleSwitch.isOn = isOn
        self.onToggle = onToggle
    }

    @objc private func switchToggled() {
        onToggle?(toggleSwitch.isOn)
    }
}
