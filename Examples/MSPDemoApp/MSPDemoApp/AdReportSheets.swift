import UIKit

// MARK: - Entry Point

enum AdReportFlow {
    /// Present the two-stage report flow from any view controller.
    /// `onReport` is called with the selected reason string after the user confirms.
    static func present(
        from presentingVC: UIViewController,
        onReport: @escaping (String) -> Void
    ) {
        let firstSheet = AdReportFirstSheetViewController()
        firstSheet.onReport = { [weak presentingVC] in
            guard let presentingVC else { return }
            let reasonVC = AdReportReasonSheetViewController()
            reasonVC.onSelect = onReport
            let nav = UINavigationController(rootViewController: reasonVC)
            nav.modalPresentationStyle = .pageSheet
            if let sheet = nav.sheetPresentationController {
                if #available(iOS 16, *) {
                    let height: CGFloat = 44 + CGFloat(AdReportReasonSheetViewController.reasons.count) * 52 + 60
                    sheet.detents = [.custom(identifier: .init("reasons")) { _ in height }]
                } else {
                    sheet.detents = [.medium()]
                }
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 16
            }
            presentingVC.present(nav, animated: true)
        }
        presentingVC.present(firstSheet, animated: true)
    }
}

// MARK: - First Sheet: Hide / Report

private final class AdReportFirstSheetViewController: UITableViewController {

    var onHide: (() -> Void)?
    var onReport: (() -> Void)?

    private enum Row: Int, CaseIterable {
        case hide, report

        var title: String {
            switch self {
            case .hide: return "Hide this ad"
            case .report: return "Report this ad"
            }
        }

        var icon: String {
            switch self {
            case .hide: return "eye.slash"
            case .report: return "exclamationmark.triangle"
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.isScrollEnabled = false
        tableView.rowHeight = 52
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        setupSheet()
    }

    private func setupSheet() {
        guard let sheet = sheetPresentationController else { return }
        if #available(iOS 16, *) {
            let height = CGFloat(Row.allCases.count) * 52 + 44
            sheet.detents = [.custom(identifier: .init("adOptions")) { _ in height }]
        } else {
            sheet.detents = [.medium()]
        }
        sheet.prefersGrabberVisible = true
        sheet.preferredCornerRadius = 16
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Row.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        guard let row = Row(rawValue: indexPath.row) else { return cell }
        var config = UIListContentConfiguration.cell()
        config.text = row.title
        config.image = UIImage(systemName: row.icon)
        config.imageProperties.tintColor = .label
        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Row(rawValue: indexPath.row) {
        case .hide:
            dismiss(animated: true) { [weak self] in self?.onHide?() }
        case .report:
            dismiss(animated: true) { [weak self] in self?.onReport?() }
        case .none:
            break
        }
    }
}

// MARK: - Second Sheet: Reason Selection

final class AdReportReasonSheetViewController: UITableViewController {

    var onSelect: ((String) -> Void)?

    static let reasons: [(title: String, value: String)] = [
        ("Scam", "scam"),
        ("Irrelevant", "irrelevant"),
        ("Repetitive", "repetitive"),
        ("Inappropriate", "inappropriate"),
        ("Other", "other_feedback"),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Report this ad"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )
        tableView.isScrollEnabled = false
        tableView.rowHeight = 52
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        setupHeader()
    }

    private func setupHeader() {
        let label = UILabel()
        label.text = "Help us understand why you want to report this ad."
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center

        let container = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 60))
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        tableView.tableHeaderView = container
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Self.reasons.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = UIListContentConfiguration.cell()
        config.text = Self.reasons[indexPath.row].title
        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let reason = Self.reasons[indexPath.row].value
        dismiss(animated: true) { [weak self] in
            self?.onSelect?(reason)
        }
    }
}
