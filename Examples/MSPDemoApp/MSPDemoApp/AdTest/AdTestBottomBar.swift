import MSPSnapKit
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

        loadShowButton.addAction(UIAction { [weak self] _ in self?.onLoadShow?() }, for: .touchUpInside)
        destroyButton.addAction(UIAction { [weak self] _ in self?.onDestroy?() }, for: .touchUpInside)

        let btnStack = UIStackView(arrangedSubviews: [loadShowButton, destroyButton])
        btnStack.axis = .horizontal
        btnStack.spacing = 12
        btnStack.distribution = .fillEqually

        addSubview(topLine)
        addSubview(btnStack)

        topLine.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(0.5)
        }
        btnStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.height.equalTo(48)
        }
    }
}
