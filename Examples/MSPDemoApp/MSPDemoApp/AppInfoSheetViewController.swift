import MSPiOSCore
import MSPSnapKit
import UIKit

final class AppInfoSheetViewController: UIViewController {

    // MARK: - Data

    private struct Row {
        let label: String
        let keyPath: KeyPath<AppInfoSheetViewController, String>
    }

    private let sections: [(title: String, rows: [Row])] = [
        (title: "App", rows: [
            Row(label: "Version", keyPath: \.appVersion),
        ]),
        (title: "SDK", rows: [
            Row(label: "msp_id", keyPath: \.mspId),
            Row(label: "msp_user_id", keyPath: \.mspUserId),
        ]),
    ]

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(v) (\(b))"
    }

    private var mspId: String {
        UserDefaults.standard.string(forKey: MSPConstants.USER_DEFAULTS_KEY_MSP_ID) ?? "Fetching…"
    }

    private var mspUserId: String {
        UserDefaults.standard.string(forKey: MSPConstants.USER_DEFAULTS_KEY_MSP_USER_ID) ?? "Fetching…"
    }

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var observer: NSObjectProtocol?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "App Info"
        view.backgroundColor = .systemGroupedBackground
        setupTableView()
        setupCloseButton()
        startObservingIfNeeded()
    }

    deinit {
        stopObserving()
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.isScrollEnabled = false
        tableView.allowsSelection = false
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func setupCloseButton() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )
    }

    // MARK: - UserDefaults observation

    private func startObservingIfNeeded() {
        guard mspId == "Fetching…" || mspUserId == "Fetching…" else { return }
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.tableView.reloadData()
            if self.mspId != "Fetching…" && self.mspUserId != "Fetching…" {
                self.stopObserving()
            }
        }
    }

    private func stopObserving() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
}

// MARK: - UITableViewDataSource

extension AppInfoSheetViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let row = sections[indexPath.section].rows[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = row.label
        content.secondaryText = self[keyPath: row.keyPath]
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = content
        return cell
    }
}
