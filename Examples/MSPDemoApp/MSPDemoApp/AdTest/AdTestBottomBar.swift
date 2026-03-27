import UIKit

final class AdTestBottomBar: UIView {
    var onLoadShow: (() -> Void)?
    var onDestroy: (() -> Void)?

    private let loadShowButton: UIButton
    private let destroyButton: UIButton

    override init(frame: CGRect) {
        var loadConfig = UIButton.Configuration.filled()
        loadConfig.title = "Load Ad"
        loadConfig.cornerStyle = .medium
        loadShowButton = UIButton(configuration: loadConfig)

        var destroyConfig = UIButton.Configuration.bordered()
        destroyConfig.title = "Destroy Ad"
        destroyConfig.cornerStyle = .medium
        destroyButton = UIButton(configuration: destroyConfig)

        super.init(frame: frame)
        backgroundColor = .systemGroupedBackground
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(loadShowTitle: String, loadShowEnabled: Bool, destroyEnabled: Bool) {
        var cfg = loadShowButton.configuration
        cfg?.title = loadShowTitle
        loadShowButton.configuration = cfg
        loadShowButton.isEnabled = loadShowEnabled
        destroyButton.isEnabled = destroyEnabled
    }

    private func setupLayout() {
        let topLine = UIView()
        topLine.backgroundColor = .separator
        topLine.translatesAutoresizingMaskIntoConstraints = false

        loadShowButton.translatesAutoresizingMaskIntoConstraints = false
        loadShowButton.addAction(UIAction { [weak self] _ in self?.onLoadShow?() }, for: .touchUpInside)

        destroyButton.translatesAutoresizingMaskIntoConstraints = false
        destroyButton.addAction(UIAction { [weak self] _ in self?.onDestroy?() }, for: .touchUpInside)

        let btnStack = UIStackView(arrangedSubviews: [loadShowButton, destroyButton])
        btnStack.axis = .horizontal
        btnStack.spacing = 12
        btnStack.distribution = .fillEqually
        btnStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(topLine)
        addSubview(btnStack)

        NSLayoutConstraint.activate([
            topLine.topAnchor.constraint(equalTo: topAnchor),
            topLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            topLine.heightAnchor.constraint(equalToConstant: 0.5),
            btnStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            btnStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            btnStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            btnStack.heightAnchor.constraint(equalToConstant: 48),
        ])
    }
}
