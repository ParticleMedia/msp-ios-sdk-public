//
//  NovaAdMultipleImagesView.swift
//  NBNovaAds
//
//  Created by Shanyu Li on 2024/8/5.
//

import UIKit

protocol NovaAdMultipleImagesViewDelegate: AnyObject {
    func multipleImagesView(_ imagesView: NovaAdMultipleImagesView, isAutoPlayingOn index: Int, progress: Float)
}

class NovaAdMultipleImagesView: UIView {
    private lazy var mainView: UICollectionView = {
        let mainView = UICollectionView(frame: bounds, collectionViewLayout: flowLayout)
        mainView.backgroundColor = .clear
        mainView.isPagingEnabled = true
        mainView.showsHorizontalScrollIndicator = false
        mainView.showsVerticalScrollIndicator = false
        mainView.delegate = self
        mainView.dataSource = self
        mainView.scrollsToTop = true
        mainView
            .register(
                NovaAdMultipleImagesViewCell.self,
                forCellWithReuseIdentifier: NSStringFromClass(NovaAdMultipleImagesViewCell.self)
            )
        return mainView
    }()

    private lazy var flowLayout: UICollectionViewFlowLayout = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.minimumLineSpacing = 0
        flowLayout.scrollDirection = .horizontal
        return flowLayout
    }()

    private var imageURLExtractor: ImageURLExtractor?

    private var mediaModel: NovaAdMultipleImagesMediaModel?
    private var actionContext: NovaAdMediaActionContext?
    private var actionHelper: NovaActionHelper<NovaActionState.Init>?
    private var scrollTimer: Timer?
    private var lastChangingPageDate: Date?
    private var progressTimer: Timer?
    weak var delegate: NovaAdMultipleImagesViewDelegate?

    init() {
        super.init(frame: .zero)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        scrollTimer?.invalidate()
        progressTimer?.invalidate()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let imageURLExtractor, mainView.contentOffset.x == 0 {
            let targetIndex = imageURLExtractor.totalItemsCount / 2
            mainView
                .scrollToItem(at: IndexPath(item: targetIndex, section: 0), at: .centeredHorizontally, animated: false)
        }
    }

    /// Render the multiple images view
    /// - Parameters:
    ///   - imageURLs: URL of images to show
    ///   - timerInterval: If you want the multiple image view to auto scroll, set the timerInterval
    func render(with mediaModel: NovaAdMultipleImagesMediaModel, actionContext: NovaAdMediaActionContext?) {
        self.mediaModel = mediaModel
        invalidateTimer()
        self.imageURLExtractor = ImageURLExtractor(imageURLs: mediaModel.imageURLs)
        if mediaModel.imageURLs.count > 1 {
            mainView.isScrollEnabled = true
            setupTimer()
        } else {
            mainView.isScrollEnabled = false
        }

        setupActionHelper()
        mainView.reloadData()
    }

    // TODO: lsy, 之前会调用 immersive 的 展示 cta button 的方法
}

private extension NovaAdMultipleImagesView {
    func setupSubviews() {
        addSubview(mainView)
        mainView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setupTimer() {
        invalidateTimer()
        if let timerInterval = mediaModel?.timerInterval {
            lastChangingPageDate = Date()
            self.scrollTimer = Timer.scheduledTimer(
                timeInterval: timerInterval,
                target: self,
                selector: #selector(scrollTimerAction),
                userInfo: nil,
                repeats: true
            )
            self.progressTimer =
                Timer
                .scheduledTimer(
                    timeInterval: 0.1,
                    target: self,
                    selector: #selector(progressTimerAction),
                    userInfo: nil,
                    repeats: true
                )
        }
    }

    func invalidateTimer() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil
    }

    func getCurrentCellIndex() -> Int {
        if mainView.frame.width == 0 || mainView.frame.width == 0 {
            return 0
        }

        let index = Int(
            (mainView.contentOffset.x + mainView.bounds.size.width * 0.5) / mainView.bounds.size.width
        )
        return max(0, index)
    }

    func scroll(to targetIndex: Int) {
        guard let imageURLExtractor else { return }
        var targetIndex = targetIndex
        if targetIndex >= imageURLExtractor.totalItemsCount {
            targetIndex = imageURLExtractor.totalItemsCount / 2
            mainView
                .scrollToItem(at: IndexPath(item: targetIndex, section: 0), at: .centeredHorizontally, animated: false)
        } else {
            mainView
                .scrollToItem(at: IndexPath(item: targetIndex, section: 0), at: .centeredHorizontally, animated: true)
        }
    }

    func setupActionHelper() {
        guard let actionContext else {
            DebugLogger.ui.info("multiple images view is not clickable without action Context, but tapped")
            return
        }
        guard let mediaModel else {
            DebugLogger.ui.info("multiple images view is not set, but image tapped")
            return
        }

        if let weakVC = actionContext.viewController {
            actionHelper =
                NovaActionHelper
                .build(
                    with:
                        .adInViewController(
                            model: .init(
                                tracingInfo: actionContext.adActionTracingInfo,
                                extraInfo: actionContext.adActionExtraInfo,
                                ctrType: mediaModel.adCtrType
                            ),
                            viewController: weakVC
                        )
                )
        } else {
            actionHelper =
                NovaActionHelper
                .build(
                    with:
                        .adInView(
                            model: .init(
                                tracingInfo: actionContext.adActionTracingInfo,
                                extraInfo: actionContext.adActionExtraInfo,
                                ctrType: mediaModel.adCtrType
                            )
                        )
                )
        }
    }

    @objc func scrollTimerAction() {
        guard let imageURLExtractor else {
            return
        }
        scroll(to: getCurrentCellIndex() + 1)
        imageURLExtractor.indexOfCurrentImage += 1
        lastChangingPageDate = Date()
    }

    @objc func progressTimerAction() {
        if let lastChangingPageDate, let timerInterval = mediaModel?.timerInterval, let imageURLExtractor {
            delegate?
                .multipleImagesView(
                    self,
                    isAutoPlayingOn: imageURLExtractor.indexOfCurrentImage,
                    progress: Float((Date().timeIntervalSince(lastChangingPageDate)) / timerInterval)
                )
        }
    }
}

extension NovaAdMultipleImagesView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        imageURLExtractor?.totalItemsCount ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        guard
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: NSStringFromClass(NovaAdMultipleImagesViewCell.self),
                for: indexPath
            ) as? NovaAdMultipleImagesViewCell
        else {
            return UICollectionViewCell()
        }
        if let url = imageURLExtractor?.getImageURL(with: indexPath.item) {
            cell.setImage(with: url)
        }
        return cell
    }
}

extension NovaAdMultipleImagesView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        actionHelper = actionHelper?.logNovaClickEvent(in: .media).handleAdTap(in: self)
    }

    func collectionView(
        _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        collectionView.bounds.size
    }
}

extension NovaAdMultipleImagesView: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        invalidateTimer()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        setupTimer()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollViewDidEndScrollingAnimation(scrollView)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard let imageURLExtractor else {
            return
        }

        imageURLExtractor.indexOfCurrentImage = getCurrentCellIndex()
    }
}

private class ImageURLExtractor {
    private let imageURLs: [URL]
    private var _indexOfCurrentImage: Int
    var indexOfCurrentImage: Int {
        get { _indexOfCurrentImage }
        set {
            _indexOfCurrentImage = newValue % imageURLs.count
        }
    }
    let totalItemsCount: Int

    init(imageURLs: [URL]) {
        self.imageURLs = imageURLs
        self._indexOfCurrentImage = 0
        self.totalItemsCount = imageURLs.count * 100
    }

    func getImageURL(with index: Int) -> URL {
        imageURLs[getImageIndex(with: index)]
    }

    private func getImageIndex(with item: Int) -> Int {
        item % imageURLs.count
    }
}
