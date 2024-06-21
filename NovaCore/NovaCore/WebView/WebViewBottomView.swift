import Foundation
import UIKit

public protocol WebViewBottomViewDelegate: AnyObject {
    func bottomViewDidTapBackButton()
    func bottomViewDidTapForwardButton()
}

public class WebViewBottomView: UIView {
    // MARK: - Constants

    private enum Constants {
        static let buttonDisableColor = UIColor(light: ColorPalettes.Gray.tint200, dark: ColorPalettes.Gray.tint500)
        static let buttonEnableColor = UIColor(light: ColorPalettes.Black, dark: ColorPalettes.White)
    }

    // MARK: - Properties

    public weak var delegate: WebViewBottomViewDelegate?

    private let backButton: UIButton = {
        let button = UIButton()
        button.setImage(.NB.chevronLeftLine?.withTintColor(Constants.buttonDisableColor), for: .disabled)
        button.setImage(.NB.chevronLeftLine?.withTintColor(Constants.buttonEnableColor), for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        button.isEnabled = false
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let forwardButton: UIButton = {
        let button = UIButton()
        button.setImage(.NB.chevronRightLine?.withTintColor(Constants.buttonDisableColor), for: .disabled)
        button.setImage(.NB.chevronRightLine?.withTintColor(Constants.buttonEnableColor), for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        button.isEnabled = false
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var containerView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [backButton, forwardButton])
        view.axis = .horizontal
        view.alignment = .center
        view.spacing = 28
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)

        backButton.addTarget(self, action: #selector(didTapBackButton), for: .touchUpInside)
        forwardButton.addTarget(self, action: #selector(didTapForwardButton), for: .touchUpInside)

        backgroundColor = UIColor(light: ColorPalettes.Gray.tint100, dark: ColorPalettes.Gray.tint700)

        addSubview(containerView)

        NSLayoutConstraint.activate([
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        NSLayoutConstraint.activate([
            forwardButton.widthAnchor.constraint(equalToConstant: 44),
            forwardButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Public functions

public extension WebViewBottomView {
    func configButton(canGoBack: Bool? = nil, canGoForward: Bool? = nil) {
        if let canGoBack {
            backButton.isEnabled = canGoBack
        }

        if let canGoForward {
            forwardButton.isEnabled = canGoForward
        }
    }
}

// MARK: - Private functions

private extension WebViewBottomView {
    @objc func didTapBackButton() {
        delegate?.bottomViewDidTapBackButton()
    }

    @objc func didTapForwardButton() {
        delegate?.bottomViewDidTapForwardButton()
    }
}
