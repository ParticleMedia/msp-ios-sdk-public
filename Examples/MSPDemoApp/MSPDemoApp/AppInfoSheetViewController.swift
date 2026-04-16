import MSPiOSCore
import MSPSnapKit
import UIKit

final class AppInfoSheetViewController: UIViewController {

    // MARK: - Data

    private struct Row {
        let label: String
        let keyPath: KeyPath<AppInfoSheetViewController, String>
        var copyable: Bool = false
    }

    private let sections: [(title: String, rows: [Row])] = [
        (title: "App", rows: [
            Row(label: "Version", keyPath: \.appVersion),
        ]),
        (title: "SDK", rows: [
            Row(label: "MSP ID", keyPath: \.mspId, copyable: true),
            Row(label: "SHORT ID", keyPath: \.shortId, copyable: true),
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

    private var shortId: String {
        guard let mspIdStr = UserDefaults.standard.string(forKey: MSPConstants.USER_DEFAULTS_KEY_MSP_ID),
              let value = Int64(mspIdStr) else { return "Fetching…" }
        return String(value & 0xFFFFFFFFF)
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
        guard mspId == "Fetching…" || shortId == "Fetching…" else { return }
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.tableView.reloadData()
            if self.mspId != "Fetching…" && self.shortId != "Fetching…" {
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

    // MARK: - Copy & Toast

    private func copyToClipboard(_ value: String) {
        UIPasteboard.general.string = value
        showToast("Copied!", from: self)
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

        if row.copyable {
            let button = UIButton(type: .system)
            let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            button.setImage(UIImage(systemName: "doc.on.doc", withConfiguration: config), for: .normal)
            button.tintColor = .secondaryLabel
            button.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
            button.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.copyToClipboard(self[keyPath: row.keyPath])
            }, for: .touchUpInside)
            cell.accessoryView = button
        } else {
            cell.accessoryView = nil
        }

        return cell
    }
}
