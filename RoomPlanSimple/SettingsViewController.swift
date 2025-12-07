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
        case language
        case about

        var title: String {
            switch self {
            case .scanning: return L10n.Settings.scanning.localized
            case .saving: return L10n.Settings.saving.localized
            case .language: return L10n.Settings.language.localized
            case .about: return L10n.Settings.about.localized
            }
        }
    }

    private enum ScanningRow: Int, CaseIterable {
        case defaultWifiTracking
    }

    private enum SavingRow: Int, CaseIterable {
        case autoSave
        case iCloudSync
    }

    private enum LanguageRow: Int, CaseIterable {
        case appLanguage
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
        title = L10n.Settings.title.localized
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
        case .language: return LanguageRow.allCases.count
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

        case .language:
            guard let row = LanguageRow(rawValue: indexPath.row) else { return UITableViewCell() }
            return configureLanguageCell(for: row, at: indexPath)

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
                title: L10n.Settings.WiFiTracking.title.localized,
                subtitle: L10n.Settings.WiFiTracking.subtitle.localized,
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
                title: L10n.Settings.AutoSave.title.localized,
                subtitle: L10n.Settings.AutoSave.subtitle.localized,
                isOn: settings.autoSaveScans
            ) { [weak self] isOn in
                self?.settings.autoSaveScans = isOn
            }
            return cell

        case .iCloudSync:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchCell
            let subtitle: String
            if settings.isICloudAvailable {
                subtitle = L10n.Settings.ICloud.subtitle.localized
            } else {
                subtitle = L10n.Settings.ICloud.unavailable.localized
            }
            cell.configure(
                title: L10n.Settings.ICloud.title.localized,
                subtitle: subtitle,
                isOn: settings.iCloudSyncEnabled
            ) { [weak self] isOn in
                guard let self = self else { return }
                if isOn && !self.settings.isICloudAvailable {
                    // Show alert that iCloud is not available
                    self.showICloudNotAvailableAlert()
                    // Reset toggle
                    cell.switchControl.setOn(false, animated: true)
                } else {
                    self.settings.iCloudSyncEnabled = isOn
                }
            }
            // Disable toggle if iCloud not available
            cell.switchControl.isEnabled = settings.isICloudAvailable
            return cell
        }
    }

    private func configureLanguageCell(for row: LanguageRow, at indexPath: IndexPath) -> UITableViewCell {
        switch row {
        case .appLanguage:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            var content = cell.defaultContentConfiguration()
            content.text = L10n.Settings.AppLanguage.title.localized
            content.secondaryText = settings.appLanguage.displayName
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }

    private func configureAboutCell(for row: AboutRow, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        var content = cell.defaultContentConfiguration()

        switch row {
        case .version:
            content.text = L10n.Settings.version.localized
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            content.secondaryText = "\(version) (\(build))"
            cell.selectionStyle = .none

        case .resetSettings:
            content.text = L10n.Settings.reset.localized
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

        switch section {
        case .language:
            if let row = LanguageRow(rawValue: indexPath.row), row == .appLanguage {
                showLanguagePicker()
            }
        case .about:
            if let row = AboutRow(rawValue: indexPath.row), row == .resetSettings {
                confirmResetSettings()
            }
        default:
            break
        }
    }

    private func confirmResetSettings() {
        let alert = UIAlertController(
            title: L10n.Settings.ResetConfirm.title.localized,
            message: L10n.Settings.ResetConfirm.message.localized,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: L10n.Common.cancel.localized, style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.Settings.ResetConfirm.reset.localized, style: .destructive) { [weak self] _ in
            self?.settings.resetToDefaults()
            self?.tableView.reloadData()
        })

        present(alert, animated: true)
    }

    private func showICloudNotAvailableAlert() {
        let alert = UIAlertController(
            title: L10n.Settings.ICloud.notAvailableTitle.localized,
            message: L10n.Settings.ICloud.notAvailableMessage.localized,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.Common.ok.localized, style: .default))
        present(alert, animated: true)
    }

    private func showLanguagePicker() {
        let alert = UIAlertController(
            title: L10n.Settings.AppLanguage.title.localized,
            message: L10n.Settings.AppLanguage.subtitle.localized,
            preferredStyle: .actionSheet
        )

        // Add all available languages using the enum
        for language in AppSettings.AppLanguage.allCases {
            alert.addAction(UIAlertAction(title: language.displayName, style: .default) { [weak self] _ in
                self?.changeLanguage(to: language)
            })
        }

        alert.addAction(UIAlertAction(title: L10n.Common.cancel.localized, style: .cancel))

        // For iPad
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = tableView
            popoverController.sourceRect = tableView.rectForRow(at: IndexPath(row: 0, section: Section.language.rawValue))
        }

        present(alert, animated: true)
    }

    private func changeLanguage(to language: AppSettings.AppLanguage) {
        settings.appLanguage = language
        tableView.reloadData()

        // Show restart prompt
        let alert = UIAlertController(
            title: L10n.Settings.LanguageRestart.title.localized,
            message: L10n.Settings.LanguageRestart.message.localized,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: L10n.Common.ok.localized, style: .default))

        present(alert, animated: true)
    }
}

// MARK: - SwitchCell

private class SwitchCell: UITableViewCell {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let toggleSwitch = UISwitch()
    private var onToggle: ((Bool) -> Void)?

    /// Public access to the switch for external configuration
    var switchControl: UISwitch {
        return toggleSwitch
    }

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
