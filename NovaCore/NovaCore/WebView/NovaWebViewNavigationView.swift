import UIKit
import Foundation

public class NovaWebViewNavigationView: UIView {
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

    private var viewModel: NovaWebViewNavigationViewModel?
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

    public func config(viewModel: NovaWebViewNavigationViewModel) {
        self.viewModel = viewModel
        
        leftButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        rightButton.translatesAutoresizingMaskIntoConstraints = false
        divider.translatesAutoresizingMaskIntoConstraints = false

        if viewModel.includingStatusBar {
            NSLayoutConstraint.activate([
                leftButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
                leftButton.bottomAnchor.constraint(equalTo: divider.topAnchor),
                leftButton.heightAnchor.constraint(equalToConstant: 44),
                leftButton.widthAnchor.constraint(equalToConstant: 44)
            ])
        } else {
            NSLayoutConstraint.activate([
                leftButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
                leftButton.centerYAnchor.constraint(equalTo: centerYAnchor),
                leftButton.heightAnchor.constraint(equalToConstant: 44),
                leftButton.widthAnchor.constraint(equalToConstant: 44)
            ])
        }

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 56),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -56),
            titleLabel.centerYAnchor.constraint(equalTo: leftButton.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])

        NSLayoutConstraint.activate([
            rightButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            rightButton.centerYAnchor.constraint(equalTo: leftButton.centerYAnchor),
            rightButton.heightAnchor.constraint(equalToConstant: 44),
            rightButton.widthAnchor.constraint(equalToConstant: 44)
        ])

        NSLayoutConstraint.activate([
            divider.heightAnchor.constraint(equalToConstant: 1),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        if let icon = viewModel.leftButtonIcon {
            let leftButtonImage = UIImage(
                novasystemName: icon,
                tintColor: .Nova.primaryText)
            leftButton.setImage(leftButtonImage, for: .normal)
            leftButton.addTarget(self, action: #selector(didTapLeftButton), for: .touchUpInside)
        }
        leftButton.isHidden = viewModel.hideLeftButton

        if let icon = viewModel.rightButtonIcon {
            let rightButtonImage = UIImage(
                novasystemName: icon,
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
