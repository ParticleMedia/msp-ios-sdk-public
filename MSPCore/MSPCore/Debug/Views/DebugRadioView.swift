import UIKit

private enum UIConfig {
    static let radioSize: CGFloat = 20
    static let radioBorderWidth: CGFloat = 2
    static let radioSelectedColor: UIColor = .systemBlue
    static let radioUnselectedColor: UIColor = .clear
    static let radioBorderColor: UIColor = .systemGray
}

class DebugRadioView: UIView {
    var isSelected: Bool = false {
        didSet { updateAppearance() }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        layer.cornerRadius = UIConfig.radioSize / 2
        layer.borderWidth = UIConfig.radioBorderWidth
        layer.borderColor = UIConfig.radioBorderColor.cgColor
        snp.makeConstraints { make in
            make.width.height.equalTo(UIConfig.radioSize)
        }
        updateAppearance()
    }
    
    private func updateAppearance() {
        backgroundColor = isSelected ? UIConfig.radioSelectedColor : UIConfig.radioUnselectedColor
    }
} 