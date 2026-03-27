import UIKit

final class ChipFlowView: UIView {
    private var options: [String]
    private var selected: String?
    private let onSelect: (String?) -> Void
    private var chipButtons: [UIButton] = []

    private let chipSpacing: CGFloat = 8
    private let lineSpacing: CGFloat = 8
    private var computedHeight: CGFloat = 0

    init(options: [String], selected: String?, onSelect: @escaping (String?) -> Void) {
        self.options = options
        self.selected = selected
        self.onSelect = onSelect
        super.init(frame: .zero)
        buildChips()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let totalWidth = bounds.width
        guard totalWidth > 0 else { return }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for chip in chipButtons {
            let sz = chip.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
            if x + sz.width > totalWidth && x > 0 {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            chip.frame = CGRect(x: x, y: y, width: sz.width, height: sz.height)
            x += sz.width + chipSpacing
            rowHeight = max(rowHeight, sz.height)
        }

        let newHeight = chipButtons.isEmpty ? 0 : y + rowHeight
        if newHeight != computedHeight {
            computedHeight = newHeight
            invalidateIntrinsicContentSize()
            superview?.setNeedsLayout()
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: computedHeight)
    }

    func reload(options: [String], selected: String?) {
        self.options = options
        self.selected = selected
        buildChips()
    }

    private func buildChips() {
        chipButtons.forEach { $0.removeFromSuperview() }
        chipButtons = options.map { option in
            let chip = makeChip(title: option, isSelected: option == selected)
            chip.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                let next: String? = (self.selected == option) ? nil : option
                self.selected = next
                self.onSelect(next)
                self.refreshChips()
            }, for: .touchUpInside)
            addSubview(chip)
            return chip
        }
        setNeedsLayout()
    }

    private func refreshChips() {
        for (i, btn) in chipButtons.enumerated() {
            applyStyle(btn, isSelected: options[i] == selected)
        }
    }

    private func makeChip(title: String, isSelected: Bool) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var updated = attrs
            updated.font = .systemFont(ofSize: 13, weight: .medium)
            return updated
        }
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        let btn = UIButton(configuration: config)
        btn.layer.cornerRadius = 8
        btn.clipsToBounds = true
        btn.automaticallyUpdatesConfiguration = false
        applyStyle(btn, isSelected: isSelected)
        return btn
    }

    private func applyStyle(_ btn: UIButton, isSelected: Bool) {
        var config = btn.configuration
        config?.background.backgroundColor = isSelected ? .systemBlue : .tertiarySystemGroupedBackground
        config?.baseForegroundColor = isSelected ? .white : .label
        btn.configuration = config
    }
}
