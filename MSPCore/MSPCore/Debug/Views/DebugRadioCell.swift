import UIKit
import Combine
import SnapKit

private enum UIConfig {
    static let labelLeading: CGFloat = 16
    static let labelTrailing: CGFloat = 16
    static let labelTop: CGFloat = 8
    static let labelBottom: CGFloat = 8
    static let radioToLabelSpacing: CGFloat = 12
}

class DebugRadioCell: UITableViewCell {
    private var subscriptions = Set<AnyCancellable>()
    private let radioView = DebugRadioView()
    private let titleLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(radioView)
        contentView.addSubview(titleLabel)
        radioView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConfig.labelLeading)
            make.centerY.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(radioView.snp.trailing).offset(UIConfig.radioToLabelSpacing)
            make.trailing.equalToSuperview().inset(UIConfig.labelTrailing)
            make.top.equalToSuperview().offset(UIConfig.labelTop)
            make.bottom.equalToSuperview().inset(UIConfig.labelBottom)
        }
    }
    
    func configure(with viewModel: DebugRadioCellViewModel) {
        titleLabel.text = viewModel.title
        subscriptions.removeAll()
        viewModel.isSelectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSelected in
                self?.accessoryType = isSelected ? .checkmark : .none
                self?.radioView.isSelected = isSelected
            }
            .store(in: &subscriptions)
    }
} 
