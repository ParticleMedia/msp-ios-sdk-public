//
//  NovaAdCarouselView.swift
//  NBNovaAdMedia
//
//  Created by Shanyu Li on 2024/7/17.
//

import SnapKit
import UIKit

// MARK: - NovaAdCarouselView

class NovaAdCarouselView: UIView {
    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: .zero)

        setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    enum Constants {
        static let Padding = 14.0
    }

    // MARK: Private

    private lazy var carousel: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = Constants.Padding / 2
        layout.minimumInteritemSpacing = Constants.Padding
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.register(NovaAdCarouselCell.self, forCellWithReuseIdentifier: NSStringFromClass(NovaAdCarouselCell.self))
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        return collectionView
    }()

    private var items: [NovaNativeMultipleItemsItem]?
    private var actionContext: NovaAdMediaActionContext?
    private var actionHelper: NovaActionHelper<NovaActionState.Init>?
}

private extension NovaAdCarouselView {
    func setupSubviews() {
        addSubview(carousel)

        carousel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

extension NovaAdCarouselView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 220, height: 283)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: Constants.Padding, bottom: 0, right: Constants.Padding)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Do nothing to disable cell selection
    }
}

extension NovaAdCarouselView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: NSStringFromClass(NovaAdCarouselCell.self),
            for: indexPath
        ) as? NovaAdCarouselCell else {
            return UICollectionViewCell()
        }

        if let carouselItem = items?[safe: indexPath.item] {
            cell.delegate = self
            cell.setup(with: carouselItem)
        }
        return cell
    }
}

extension NovaAdCarouselView: NovaAdCarouselCellDelegate {
    func nativeAdCarouselCell(_ cell: NovaAdCarouselCell, didClickArea area: ClickableAdArea?) {
        guard let index = carousel.indexPath(for: cell)?.item else {
            DebugLogger.ui.error("Carousel ad click event did not find indexPath")
            return
        }
        guard let adCtrType = items?[safe: index]?.ctrType else {
            DebugLogger.ui.error("Carousel ad click event did not find item at index \(index)")
            return
        }
        guard let actionContext else {
            DebugLogger.ui.error("Carousel ad click event did not find action context")
            return
        }

        actionHelper = {
            if let weakVC = actionContext.viewController {
                return NovaActionHelper
                    .build(
                        with:
                        .adInViewController(
                            model: .init(
                                tracingInfo: actionContext.adActionTracingInfo,
                                extraInfo: actionContext.adActionExtraInfo,
                                ctrType: adCtrType
                            ),
                            viewController: weakVC
                        )
                    )
            } else {
                return NovaActionHelper
                    .build(
                        with:
                        .adInView(
                            model: .init(
                                tracingInfo: actionContext.adActionTracingInfo,
                                extraInfo: actionContext.adActionExtraInfo,
                                ctrType: adCtrType
                            )
                        )
                    )
            }
        }()

        actionHelper = actionHelper?.logNovaClickEvent(in: .media).handleAdTap(in: cell)
    }
}

extension NovaAdCarouselView: AnyMultipleItemsView {
    func config(
        with model: NovaAdMultipleItemsMediaModel,
        actionContext: NovaAdMediaActionContext?,
        completion: @escaping () -> Void
    ) {
        self.items = model.info.items
        self.actionContext = actionContext
        carousel.reloadData()
        // NOTE: (shanyu.li) run in next runloop
        DispatchQueue.main.async {
            completion()
        }
    }
}
