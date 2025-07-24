import UIKit
import SnapKit

class DebugSectionHeaderView: UIView {
    // MARK: - Properties
    private let titleLabel = UILabel()
    private let disclosureIndicator = UIImageView()
    var isExpanded: Bool = true {
        didSet {
            updateDisclosureIndicator()
        }
    }
    var title: String? {
        didSet {
            titleLabel.text = title
        }
    }
    var tapAction: (() -> Void)?
    private var isPlacementSection: Bool = false
    
    // MARK: - Initialization
    init(isPlacementSection: Bool = false) {
        self.isPlacementSection = isPlacementSection
        super.init(frame: .zero)
        setupView()
        setupConstraints()
        setupGestureRecognizer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupView() {
        backgroundColor = .systemBackground
        
        // Title Label
        titleLabel.font = .boldSystemFont(ofSize: 16)
        addSubview(titleLabel)
        
        // Disclosure Indicator (only for placement section)
        if isPlacementSection {
            disclosureIndicator.image = UIImage(systemName: "chevron.down")
            disclosureIndicator.tintColor = .systemGray
            disclosureIndicator.contentMode = .scaleAspectFit
            addSubview(disclosureIndicator)
        }
    }
    
    private func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(self).offset(16)
            make.trailing.equalTo(self).offset(-16)
            make.top.equalTo(self).offset(10)
            make.bottom.equalTo(self).offset(-10)
        }
        
        if isPlacementSection {
            disclosureIndicator.snp.makeConstraints { make in
                make.trailing.equalTo(self).offset(-16)
                make.centerY.equalTo(titleLabel)
                make.width.height.equalTo(20)
            }
        }
    }
    
    private func setupGestureRecognizer() {
        if isPlacementSection {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(headerTapped))
            addGestureRecognizer(tapGesture)
            isUserInteractionEnabled = true
        }
    }
    
    // MARK: - Actions
    @objc private func headerTapped() {
        tapAction?()
    }
    
    // MARK: - Helper
    private func updateDisclosureIndicator() {
        if isPlacementSection {
            disclosureIndicator.image = isExpanded ? UIImage(systemName: "chevron.down") : UIImage(systemName: "chevron.right")
        }
    }
}