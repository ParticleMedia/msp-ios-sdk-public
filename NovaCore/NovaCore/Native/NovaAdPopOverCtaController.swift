//
//  NovaVideoViewPopOverCtaController.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 7/2/25.
//
import UIKit

public class NovaAdPopOverCtaController: UIViewController {
    
    public init(passthroughViews: [UIView]) {
        self.passthroughViews = passthroughViews
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .popover
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Public
    
    public var rootViewController: UIViewController?
    
    public enum State {
        case hide
        case pop(source: (UIView, CGRect))
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()

        //view.adClickArea = .cta_popover
        view.backgroundColor = NovaColorPalettes.White

        
        view.addSubviews(label, arrowImageView)
        view.adClickArea = .cta_popover
        
        label.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Label constraints
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.horizontalPadding),
            label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Constants.verticalPadding),
            label.trailingAnchor.constraint(lessThanOrEqualTo: arrowImageView.leadingAnchor, constant: -Constants.spacing),

            // Arrow image constraints
            arrowImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.horizontalPadding),
            arrowImageView.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: Constants.imageSize),
            arrowImageView.heightAnchor.constraint(equalToConstant: Constants.imageSize)
        ])
    }
    
    public func config(with title: String) {
        label.text = title
        let labelSize = label.sizeThatFits(
            .init(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        )
        let size = CGSize(
            width: labelSize.width + Constants.spacing + Constants.imageSize + 2 * Constants.horizontalPadding,
            height: max(labelSize.height, Constants.imageSize) + 2 * Constants.verticalPadding
        )
        preferredContentSize = size
    }

    public func changeState(to state: State) {
        switch state {
        case .hide:
            dismiss(animated: true)
        case .pop(source: let (sourceView, sourceRect)):
            guard view.window == nil else {
                break
            }

            popoverPresentationController?.permittedArrowDirections = .up
            popoverPresentationController?.backgroundColor = .clear
            popoverPresentationController?.passthroughViews = self.passthroughViews
            //popoverPresentationController?.delegate = delegate
            popoverPresentationController?.sourceView = sourceView
            popoverPresentationController?.sourceRect = sourceRect
            let viewController = self.rootViewController ?? UIApplication.novakeyRootViewController
            popoverPresentationController?.delegate = self
            viewController?.present(self, animated: true)
            //NBUtil.topViewController()?.present(self, animated: true)
        }
    }
    
    public var tappableView: UIView {
        return self.view
    }
    
    // MARK: Private
    var passthroughViews: [UIView]
    
    private enum Constants {
        static let horizontalPadding = 14.0
        static let verticalPadding = 8.0
        static let spacing = 4.0
        static let imageSize = 16.0
    }

    private lazy var label: UILabel = {
        let label = UILabel()
        label.font = .Nova.subtitle1
        label.textColor = NovaColorPalettes.Black.withAlphaComponent(0.85)
        return label
    }()

    private lazy var arrowImageView: UIImageView = {
        let imageView = UIImageView(image: .Nova.chevronRightLine?.withTintColor(NovaColorPalettes.Black))
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    //private let delegate: NovaAdPopOverCtaControllerDelegate?
}


// MARK: - NovaAdPopOverCtaControllerDelegate

extension NovaAdPopOverCtaController: UIPopoverPresentationControllerDelegate {
    // MARK: Public

    public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    public func popoverPresentationControllerShouldDismissPopover(
        _ popoverPresentationController: UIPopoverPresentationController
    ) -> Bool {
        return true
    }

    // MARK: Internal

    public func presentationController(
        _ controller: UIPresentationController,
        willPresentWithAdaptiveStyle style: UIModalPresentationStyle,
        transitionCoordinator: UIViewControllerTransitionCoordinator?
    ) {
        controller.containerView?.subviews.forEach { view in
            if view is UIVisualEffectView {
                view.isHidden = true
            }
        }
    }
}
