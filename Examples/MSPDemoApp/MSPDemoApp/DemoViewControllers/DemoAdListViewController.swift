// MARK: - DemoAdListViewController

/// A collection view that displays ads every 4th cell (3 placeholders + 1 ad).
/// Used to test cell reuse behavior for native ad metric reporters.
import Foundation
import MSPCore
import MSPiOSCore
import UIKit

class DemoAdListViewController: UIViewController {
    // MARK: - Constants

    private enum Layout {
        static let totalItems = 40
        static let adInterval = 4  // every 4th item is an ad (index 3, 7, 11, ...)
        static let placementId = "demo-ios-foryou-large"
        static let testParams: [String: String] = [
            "test": "{\"ad_network\":\"msp_nova\",\"test_ad\":true,\"creative_type\":\"video\",\"is_vertical\":true}"
        ]
    }

    // MARK: - Properties

    private var collectionView: UICollectionView!
    private var loadedAds: [Int: NativeAd] = [:]
    private var failedAds: [Int: String] = [:]
    private var adLoaders: [Int: MSPAdLoader] = [:]
    private var adListeners: [Int: AdPositionListener] = [:]

    /// Ad positions waiting to load, processed one at a time to avoid auction timeout
    private var pendingAdPositions: [Int] = []
    private var isLoadingAd = false
    private var hasAppeared = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Ad List (Reuse Test)"
        view.backgroundColor = .systemBackground
        setupCollectionView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reload to simulate cell reuse when returning from ad landing page
        if hasAppeared {
            collectionView.reloadData()
        }
        hasAppeared = true
    }

    // MARK: - Setup

    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(250)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(250)
            )
            let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 8
            section.contentInsets = .init(top: 8, leading: 16, bottom: 8, trailing: 16)
            return section
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(PlaceholderCell.self, forCellWithReuseIdentifier: PlaceholderCell.reuseId)
        collectionView.register(AdCell.self, forCellWithReuseIdentifier: AdCell.reuseId)

        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Ad Loading (serial queue)

    private func isAdPosition(_ index: Int) -> Bool {
        index % Layout.adInterval == (Layout.adInterval - 1)
    }

    private func enqueueAdLoadIfNeeded(position: Int) {
        guard isAdPosition(position),
            loadedAds[position] == nil,
            failedAds[position] == nil,
            !pendingAdPositions.contains(position),
            adLoaders[position] == nil
        else { return }
        pendingAdPositions.append(position)
        loadNextAd()
    }

    private func loadNextAd() {
        guard !isLoadingAd, let position = pendingAdPositions.first else { return }
        pendingAdPositions.removeFirst()
        isLoadingAd = true

        let loader = MSPAdLoader()
        adLoaders[position] = loader

        var testParams: [String: String] = Layout.testParams
        testParams["mobilefuse"] = "true"

        var customParams: [String: Any] = [:]
        customParams[MSPConstants.GOOGLE_AD_MULTI_CONTENT_URLS] = [
            "https://www.google.com", "https://newsbreak.com",
        ]

        let adRequest = AdRequest(
            customParams: customParams,
            geo: nil,
            context: nil,
            adaptiveBannerSize: AdSize(
                width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
            adSize: AdSize(
                width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
            placementId: Layout.placementId,
            adFormat: .native,
            testParams: testParams
        )

        let listener = AdPositionListener(position: position, controller: self)
        adListeners[position] = listener

        loader.loadAd(
            placementId: Layout.placementId,
            adListener: listener,
            adRequest: adRequest
        )
    }

    fileprivate func handleAdLoaded(position: Int, placementId: String) {
        guard let loader = adLoaders[position],
            let ad = loader.getAd(placementId: placementId),
            let nativeAd = ad as? NativeAd
        else {
            handleAdError(position: position, msg: "getAd returned nil or not NativeAd")
            return
        }

        adListeners.removeValue(forKey: position)
        loadedAds[position] = nativeAd
        collectionView.reloadItems(at: [IndexPath(item: position, section: 0)])

        isLoadingAd = false
        loadNextAd()
    }

    fileprivate func handleAdError(position: Int, msg: String) {
        adListeners.removeValue(forKey: position)
        adLoaders.removeValue(forKey: position)
        failedAds[position] = msg
        print("[AdList] Ad load failed at position \(position): \(msg)")
        collectionView.reloadItems(at: [IndexPath(item: position, section: 0)])

        isLoadingAd = false
        loadNextAd()
    }
}

// MARK: - UICollectionViewDataSource

extension DemoAdListViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        Layout.totalItems
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        if isAdPosition(indexPath.item), let ad = loadedAds[indexPath.item] {
            let cell =
                collectionView.dequeueReusableCell(
                    withReuseIdentifier: AdCell.reuseId, for: indexPath) as! AdCell
            cell.configure(with: ad)
            return cell
        }

        let cell =
            collectionView.dequeueReusableCell(
                withReuseIdentifier: PlaceholderCell.reuseId, for: indexPath) as! PlaceholderCell
        let errorMsg = failedAds[indexPath.item]
        cell.configure(index: indexPath.item, isAdSlot: isAdPosition(indexPath.item), error: errorMsg)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension DemoAdListViewController: UICollectionViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        enqueueAdLoadIfNeeded(position: indexPath.item)
    }
}

// MARK: - Ad Listener per position

private class AdPositionListener: AdListener {
    let position: Int
    weak var controller: DemoAdListViewController?

    init(position: Int, controller: DemoAdListViewController) {
        self.position = position
        self.controller = controller
    }

    func getRootViewController() -> UIViewController? { controller }

    func onAdLoaded(placementId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.controller?.handleAdLoaded(position: self.position, placementId: placementId)
        }
    }

    func onAdLoaded(placementId: String, loadInfo: [String: Any]) {
        onAdLoaded(placementId: placementId)
    }

    func onAdLoaded(ad: MSPAd) {
        // Not used - we fetch via getAd in onAdLoaded(placementId:)
    }

    func onAdClick(ad: MSPAd) {
        print("[AdList] Ad clicked at position \(position)")
    }

    func onAdImpression(ad: MSPAd) {
        print("[AdList] Ad impression at position \(position)")
    }

    func onAdDismissed(ad: InterstitialAd) {}

    func onError(msg: String, loadInfo: [String: Any]) {
        onError(msg: msg)
    }

    func onError(msg: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.controller?.handleAdError(position: self.position, msg: msg)
        }
    }
}

// MARK: - PlaceholderCell

private final class PlaceholderCell: UICollectionViewCell {
    static let reuseId = "PlaceholderCell"

    private let label: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.textColor = .secondaryLabel
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            contentView.heightAnchor.constraint(equalToConstant: 120),
        ])
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(index: Int, isAdSlot: Bool, error: String? = nil) {
        if let error {
            label.text = "Ad Slot #\(index) failed:\n\(error)"
            label.numberOfLines = 0
            contentView.backgroundColor = .systemRed.withAlphaComponent(0.15)
        } else if isAdSlot {
            label.text = "Ad Slot #\(index) (loading...)"
            label.numberOfLines = 1
            contentView.backgroundColor = .systemYellow.withAlphaComponent(0.15)
        } else {
            label.text = "Content Cell #\(index)"
            label.numberOfLines = 1
            contentView.backgroundColor = .secondarySystemGroupedBackground
        }
    }
}

// MARK: - AdCell

private final class AdCell: UICollectionViewCell {
    static let reuseId = "AdCell"

    private var nativeAdView: NativeAdView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .systemBackground
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        nativeAdView?.removeFromSuperview()
        nativeAdView = nil
    }

    func configure(with nativeAd: NativeAd) {
        nativeAdView?.removeFromSuperview()

        let container = DemoNativeAdContainer(frame: .zero)
        let adView = NativeAdView(nativeAd: nativeAd, nativeAdContainer: container)
        nativeAdView = adView

        contentView.addSubview(adView)
        adView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            adView.topAnchor.constraint(equalTo: contentView.topAnchor),
            adView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            adView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            adView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
}
