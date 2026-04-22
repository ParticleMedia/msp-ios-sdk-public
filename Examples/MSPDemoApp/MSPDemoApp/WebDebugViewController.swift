import MSPSnapKit
import UIKit

// MARK: - SystemClipboard

// Meszaros Type: (production) — concrete ClipboardReading backed by UIPasteboard.
// Lives in the UIKit layer (VC file) to keep WebDebugViewModel Foundation-only.
struct SystemClipboard: ClipboardReading {
    var urlString: String? { UIPasteboard.general.string }
}

// MARK: - WebDebugViewController

final class WebDebugViewController: UIViewController {

    // MARK: - Sections

    private enum Section: Int, CaseIterable {
        case clipboard = 0
        case recent = 1
    }

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let inputBar = URLInputBar()
    private let emptyStateView = WebDebugEmptyStateView()

    // MARK: - ViewModel

    private var viewModel: WebDebugViewModelProtocol

    // MARK: - Init

    init(viewModel: WebDebugViewModelProtocol = WebDebugViewModel(clipboard: SystemClipboard())) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Web Debugger"
        view.backgroundColor = .systemGroupedBackground
        setupViews()
        bindViewModel()
        updateEmptyState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.refreshClipboard()
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.onUpdate = { [weak self] in
            guard let self else { return }
            self.tableView.reloadData()
            self.updateEmptyState()
        }
    }

    // MARK: - Open URL

    private func openURL(_ urlString: String) {
        guard let url = viewModel.openURL(urlString) else {
            showInvalidURLAlert()
            return
        }
        inputBar.clearText()
        view.endEditing(true)
        navigationController?.pushViewController(WebBrowserViewController(url: url), animated: true)
    }

    private func showInvalidURLAlert() {
        let alert = UIAlertController(
            title: "Invalid URL",
            message: "Please enter a valid URL starting with http:// or https://",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Empty State

    private func updateEmptyState() {
        let hasContent = viewModel.clipboardURL != nil || !viewModel.recentURLs.isEmpty
        tableView.backgroundView = hasContent ? nil : emptyStateView
    }

    // MARK: - Setup

    private func setupViews() {
        view.addSubview(tableView)
        view.addSubview(inputBar)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.keyboardDismissMode = .onDrag

        inputBar.onGo = { [weak self] in self?.openURL($0) }

        inputBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
        }

        tableView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(inputBar.snp.top)
        }
    }
}

// MARK: - UITableViewDataSource

extension WebDebugViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .clipboard: return viewModel.clipboardURL != nil ? 1 : 0
        case .recent: return viewModel.recentURLs.count
        case .none: return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .clipboard: return viewModel.clipboardURL != nil ? "From Clipboard" : nil
        case .recent: return viewModel.recentURLs.isEmpty ? nil : "Recent"
        case .none: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        switch Section(rawValue: indexPath.section) {
        case .clipboard:
            guard let url = viewModel.clipboardURL else { break }
            var content = cell.defaultContentConfiguration()
            content.image = UIImage(systemName: "doc.on.clipboard.fill")
            content.imageProperties.tintColor = .systemBlue
            content.text = url.absoluteString
            content.textProperties.color = .systemBlue
            content.textProperties.numberOfLines = 1
            content.secondaryText = "Tap to open"
            content.secondaryTextProperties.color = .secondaryLabel
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
        case .recent:
            var content = cell.defaultContentConfiguration()
            content.image = UIImage(systemName: "clock")
            content.imageProperties.tintColor = .secondaryLabel
            content.text = viewModel.recentURLs[indexPath.row]
            content.textProperties.numberOfLines = 1
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
        case .none:
            break
        }
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        Section(rawValue: indexPath.section) == .recent
    }

    func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete, Section(rawValue: indexPath.section) == .recent else { return }
        viewModel.deleteURL(at: indexPath.row)
    }
}

// MARK: - UITableViewDelegate

extension WebDebugViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section) {
        case .clipboard:
            guard let url = viewModel.clipboardURL else { return }
            openURL(url.absoluteString)
        case .recent:
            openURL(viewModel.recentURLs[indexPath.row])
        case .none:
            break
        }
    }

    func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard Section(rawValue: indexPath.section) == .recent else { return nil }
        let urlString = viewModel.recentURLs[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let copy = UIAction(title: "Copy URL", image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.string = urlString
            }
            let delete = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                guard let self,
                      let row = self.viewModel.recentURLs.firstIndex(of: urlString) else { return }
                self.viewModel.deleteURL(at: row)
            }
            return UIMenu(children: [copy, delete])
        }
    }
}

// MARK: - URLInputBar

private final class URLInputBar: UIView {

    var onGo: ((String) -> Void)?

    private let textField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "https://localhost:3000"
        tf.keyboardType = .URL
        tf.returnKeyType = .go
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.clearButtonMode = .whileEditing
        tf.font = .systemFont(ofSize: 15)
        return tf
    }()

    private let goButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Go"
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 18, bottom: 8, trailing: 18)
        return UIButton(configuration: config)
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    func clearText() { textField.text = nil }

    private func setup() {
        backgroundColor = .systemBackground

        let separator = UIView()
        separator.backgroundColor = .separator
        addSubview(separator)
        separator.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(0.5)
        }

        let fieldContainer = UIView()
        fieldContainer.backgroundColor = .tertiarySystemFill
        fieldContainer.layer.cornerRadius = 10
        fieldContainer.clipsToBounds = true

        let globe = UIImageView(image: UIImage(systemName: "globe"))
        globe.tintColor = .tertiaryLabel
        globe.contentMode = .scaleAspectFit

        fieldContainer.addSubview(globe)
        fieldContainer.addSubview(textField)

        globe.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(9)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }

        textField.snp.makeConstraints { make in
            make.leading.equalTo(globe.snp.trailing).offset(6)
            make.trailing.equalToSuperview().inset(8)
            make.top.bottom.equalToSuperview()
        }

        addSubview(fieldContainer)
        addSubview(goButton)

        fieldContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.equalToSuperview().inset(10)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(10)
            make.height.equalTo(40)
            make.trailing.equalTo(goButton.snp.leading).offset(-8)
        }

        goButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalTo(fieldContainer)
        }

        goButton.addAction(UIAction { [weak self] _ in
            self?.onGo?(self?.textField.text ?? "")
        }, for: .touchUpInside)

        textField.delegate = self
    }
}

extension URLInputBar: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        onGo?(textField.text ?? "")
        return true
    }
}

// MARK: - WebDebugEmptyStateView

private final class WebDebugEmptyStateView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        let icon = UIImageView(image: UIImage(systemName: "network"))
        icon.tintColor = .tertiaryLabel
        icon.contentMode = .scaleAspectFit

        let title = UILabel()
        title.text = "No Recent URLs"
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.textColor = .secondaryLabel
        title.textAlignment = .center

        let subtitle = UILabel()
        subtitle.text = "Copy a URL on your Mac and it'll\nappear here automatically."
        subtitle.font = .systemFont(ofSize: 14)
        subtitle.textColor = .tertiaryLabel
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, title, subtitle])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.setCustomSpacing(16, after: icon)

        addSubview(stack)
        icon.snp.makeConstraints { make in make.width.height.equalTo(52) }
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }
    }
}
