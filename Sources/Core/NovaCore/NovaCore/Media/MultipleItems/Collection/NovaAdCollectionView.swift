//
//  NovaAdCollectionView.swift
//  NBNovaAdMedia
//
//  Created by Shanyu Li on 2025/3/6.
//

@_implementationOnly import Kingfisher
@_implementationOnly import MSPSnapKit
import UIKit

// MARK: - NovaAdCollectionView

class NovaAdCollectionView: UIView {
    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(mainAndTripleStackView)
        mainAndTripleStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Private

    private lazy var mainImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(didTapMainImageView(sender:))))
        imageView.adClickArea = .media
        imageView.layer.borderWidth = 0.5
        imageView.layer.borderColor = NovaColorPalettes.Gray.tint200.cgColor
        return imageView
    }()

    private lazy var tripleView: UIStackView = {
        let makeNewImageView: () -> UIImageView = {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.isUserInteractionEnabled = true
            imageView.addGestureRecognizer(
                UITapGestureRecognizer(target: self, action: #selector(self.didTapTripleView(sender:))))
            imageView.layer.borderWidth = 0.5
            imageView.layer.borderColor = NovaColorPalettes.Gray.tint200.cgColor
            imageView.adClickArea = .media
            imageView.snp.makeConstraints { make in
                make.height.equalTo(imageView.snp.width)
            }
            return imageView
        }
        let makeNewImageViewWithMask: () -> UIImageView = {
            let image = makeNewImageView()
            let mask = UILabel()
            mask.font = .Nova.subtitle1
            mask.textColor = .white
            mask.backgroundColor = .black.withAlphaComponent(0.5)
            mask.textAlignment = .center
            mask.text = NSLocalizedString("More", comment: "")
            image.addSubview(mask)
            mask.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            return image
        }
        let stackView = UIStackView()
        stackView.addArrangedSubview(makeNewImageView())
        stackView.addArrangedSubview(makeNewImageView())
        stackView.addArrangedSubview(makeNewImageViewWithMask())
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 4.0
        return stackView
    }()

    private lazy var mainAndTripleStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [mainImageView, tripleView])
        mainImageView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.height.equalTo(mainImageView.snp.width).multipliedBy(1.0 / 2.0)
        }
        stackView.axis = .vertical
        stackView.spacing = 4.0
        return stackView
    }()

    private var actionContext: NovaAdMediaActionContext?
    private var actionHelper: NovaActionHelper<NovaActionState.Init>?
    private var mediaModel: NovaAdMultipleItemsMediaModel?
}

private extension NovaAdCollectionView {
    @objc func didTapMainImageView(sender: UITapGestureRecognizer) {
        guard let actionContext else {
            DebugLogger.ui.error("Collection ad click event did not find action context")
            return
        }
        guard let firstItemCtrType = mediaModel?.info.items[safe: 0]?.ctrType else {
            DebugLogger.ui.error("Collection ad click event did not find media model for index: 0")
            return
        }

        actionHelper = {
            if let weakVC = actionContext.viewController {
                return
                    NovaActionHelper
                    .build(
                        with:
                            .adInViewController(
                                model: .init(
                                    tracingInfo: actionContext.adActionTracingInfo,
                                    extraInfo: actionContext.adActionExtraInfo,
                                    ctrType: firstItemCtrType
                                ),
                                viewController: weakVC
                            )
                    )
            } else {
                return
                    NovaActionHelper
                    .build(
                        with:
                            .adInView(
                                model: .init(
                                    tracingInfo: actionContext.adActionTracingInfo,
                                    extraInfo: actionContext.adActionExtraInfo,
                                    ctrType: firstItemCtrType
                                )
                            )
                    )
            }
        }()

        actionHelper = actionHelper?.logNovaClickEvent(in: .media).handleAdTap(in: mainImageView)
    }

    @objc func didTapTripleView(sender: UITapGestureRecognizer) {
        let viewIndex: Int = {
            guard let view = sender.view else { return 0 }

            return tripleView.subviews.firstIndex(of: view) ?? 0
        }()

        guard let actionContext else {
            DebugLogger.ui.error("Collection ad click event did not find action context")
            return
        }
        guard let itemCtrType = mediaModel?.info.items[safe: viewIndex + 1]?.ctrType else {
            DebugLogger.ui.error("Collection ad click event did not find media model for index: \(viewIndex + 1)")
            return
        }

        actionHelper = {
            if let weakVC = actionContext.viewController {
                return
                    NovaActionHelper
                    .build(
                        with:
                            .adInViewController(
                                model: .init(
                                    tracingInfo: actionContext.adActionTracingInfo,
                                    extraInfo: actionContext.adActionExtraInfo,
                                    ctrType: itemCtrType
                                ),
                                viewController: weakVC
                            )
                    )
            } else {
                return
                    NovaActionHelper
                    .build(
                        with:
                            .adInView(
                                model: .init(
                                    tracingInfo: actionContext.adActionTracingInfo,
                                    extraInfo: actionContext.adActionExtraInfo,
                                    ctrType: itemCtrType
                                )
                            )
                    )
            }
        }()

        actionHelper = actionHelper?.logNovaClickEvent(in: .media).handleAdTap(in: tripleView.subviews[safe: viewIndex])
    }
}

extension NovaAdCollectionView: AnyMultipleItemsView {
    func config(
        with model: NovaAdMultipleItemsMediaModel,
        actionContext: NovaAdMediaActionContext?,
        completion: @escaping () -> Void
    ) {
        let items = model.info.items
        self.mediaModel = model
        self.actionContext = actionContext
        guard items.count >= 4 else {
            completion()
            return
        }

        mainImageView.kf.setImage(with: items[safe: 0]?.imageUrl)
        (tripleView.subviews[safe: 0] as? UIImageView)?.kf.setImage(with: items[safe: 1]?.imageUrl)
        (tripleView.subviews[safe: 1] as? UIImageView)?.kf.setImage(with: items[safe: 2]?.imageUrl)
        (tripleView.subviews[safe: 2] as? UIImageView)?.kf.setImage(with: items[safe: 3]?.imageUrl)

        completion()
    }
}
