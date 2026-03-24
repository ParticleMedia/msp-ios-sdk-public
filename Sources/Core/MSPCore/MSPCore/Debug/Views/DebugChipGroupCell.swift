@_implementationOnly import MSPSnapKit
import UIKit

class DebugChipGroupCell: UITableViewCell {
    var onChipTapped: ((String) -> Void)?

    private let titleLabel = UILabel()
    private let chipStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        contentView.addSubview(titleLabel)
        contentView.addSubview(chipStack)
        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(16)
            make.trailing.lessThanOrEqualToSuperview().inset(16)
        }
        chipStack.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(8)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func configure(with vm: DebugChipGroupCellViewModel) {
        titleLabel.text = vm.title
        chipStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for option in vm.options {
            let chip = makeChip(id: option.id, title: option.title, isSelected: vm.selectedId == option.id)
            chipStack.addArrangedSubview(chip)
        }
    }

    private func makeChip(id: String, title: String, isSelected: Bool) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var updated = attrs
            updated.font = .systemFont(ofSize: 13)
            return updated
        }
        let button = UIButton(configuration: config)
        button.layer.cornerRadius = 14
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemTeal.cgColor
        button.accessibilityIdentifier = id
        button.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        applyChipStyle(button, isSelected: isSelected)
        return button
    }

    private func applyChipStyle(_ button: UIButton, isSelected: Bool) {
        var config = button.configuration
        config?.background.backgroundColor = isSelected ? .systemTeal : .clear
        config?.baseForegroundColor = isSelected ? .white : .systemTeal
        button.configuration = config
    }

    @objc private func chipTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier else { return }
        onChipTapped?(id)
    }
}
