import UIKit
import Foundation

public class WebViewNavigationView: UIView {
    private let leftButton: UIButton = {
        let button = UIButton()
        button.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        return button
    }()

    private let rightButton: UIButton = {
        let button = UIButton()
        button.imageEdgeInsets = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        return button
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(light: NovaColorPalettes.Gray.tint800, dark: NovaColorPalettes.White)
        label.textAlignment = .center
        return label
    }()

    private let divider: UIView = {
        let view = UIView()
        view.backgroundColor = .Nova.secondaryDividerDeprecated
        return view
    }()

    private var viewModel: WebViewNavigationViewModel?
    private var leftButtonBottomConstraint: NSLayoutConstraint?

    override public init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor(light: NovaColorPalettes.White, dark: NovaColorPalettes.Gray.tint900)

        addSubviews([leftButton, titleLabel, divider, rightButton])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func config(viewModel: WebViewNavigationViewModel) {
        self.viewModel = viewModel
        
        if viewModel.includingStatusBar {
            leftButton.snp.makeConstraints { make in
                make.leading.equalTo(6)
                make.bottom.equalTo(self.divider.snp.top)
                make.height.width.equalTo(44)
            }
        } else {
            leftButton.snp.makeConstraints { make in
                make.leading.equalTo(6)
                make.centerY.equalToSuperview()
                make.height.width.equalTo(44)
            }
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(56)
            make.trailing.lessThanOrEqualTo(-56)
            make.centerY.equalTo(self.leftButton.snp.centerY)
            make.centerX.equalToSuperview()
        }
        rightButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalTo(self.leftButton.snp.centerY)
            make.height.width.equalTo(44)
        }
        divider.snp.makeConstraints { make in
            make.height.equalTo(1)
            make.leading.trailing.bottom.equalToSuperview()
        }

        if let icon = viewModel.leftButtonIcon {
            let leftButtonImage = UIImage(
                systemName: icon,
                tintColor: .Nova.primaryText)
            leftButton.setImage(leftButtonImage, for: .normal)
            leftButton.addTarget(self, action: #selector(didTapLeftButton), for: .touchUpInside)
        }
        leftButton.isHidden = viewModel.hideLeftButton

        if let icon = viewModel.rightButtonIcon {
            let rightButtonImage = UIImage(
                systemName: icon,
                tintColor: .Nova.primaryText)
            rightButton.setImage(rightButtonImage, for: .normal)
            rightButton.addTarget(self, action: #selector(didTapRightButton), for: .touchUpInside)
            backgroundColor = .clear
            divider.isHidden = true
        } else {
            divider.isHidden = false
        }
        titleLabel.font = .boldSystemFont(ofSize: viewModel.titleFontSize)
        setTitle(viewModel.title)
    }

    public func setTitle(_ title: String?) {
        titleLabel.text = title
    }
    
    public func changeLeftButtonVisibility(isHidden: Bool) {
        leftButton.isHidden = isHidden
    }

    @objc private func didTapLeftButton() {
        guard let viewModel, let handler = viewModel.leftButtonTapActionHandler else { return }
        handler()
    }

    @objc private func didTapRightButton() {
        guard let viewModel, let handler = viewModel.rightButtonTapActionHandler else { return }
        handler()
    }
}
