// MARK: - AdState

import Foundation
import MSPCore
import MSPiOSCore

enum AdState {
    case idle
    case loading
    case loaded(MSPAd)
    case showing(MSPAd)
    case error(String)

    var statusText: String {
        switch self {
        case .idle: return ""
        case .loading: return "Loading ad..."
        case .loaded(let ad):
            let network = (ad.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] as? String) ?? "unknown"
            return "Ad loaded: \(network)"
        case .showing(let ad):
            let network = (ad.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] as? String) ?? "unknown"
            return "Ad showing: \(network)"
        case .error(let msg):
            return "Error: \(msg)"
        }
    }

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    var currentAd: MSPAd? {
        if case .loaded(let ad) = self { return ad }
        return nil
    }
}

// MARK: - AdTestViewModel

final class AdTestViewModel {
    // MARK: - Config

    let format: AdFormat
    let placements: [String]

    // MARK: - State

    private(set) var state: AdState = .idle {
        didSet { onStateChange?(state) }
    }

    /// Bound by the VC; called on an arbitrary thread — dispatch to main before touching UI.
    var onStateChange: ((AdState) -> Void)?

    // MARK: - Ad metadata (read by VC for display)

    private(set) var selectedPlacement: String
    private(set) var loadedBannerSize = CGSize(width: 320, height: 50)

    // MARK: - Private

    private var adLoader: MSPAdLoader?

    // MARK: - Init

    init(format: AdFormat, placements: [String]) {
        self.format = format
        self.placements = placements
        self.selectedPlacement = placements.first ?? ""
    }

    // MARK: - Actions

    func selectPlacement(_ placement: String) {
        selectedPlacement = placement
        onStateChange?(state)  // refresh button enable state
    }

    func loadAd(bannerSize: CGSize, novaSandbox: Bool, params: TestParams, htmlTestAdString: String? = nil, adListener: AdListener) {
        state = .loading
        loadedBannerSize = bannerSize

        let loader = MSPAdLoader()
        adLoader = loader

        let adSize = AdSize(
            width: Int(bannerSize.width),
            height: Int(bannerSize.height),
            isInlineAdaptiveBanner: false,
            isAnchorAdaptiveBanner: false
        )
        var customParams: [String: Any] = [
            MSPConstants.GOOGLE_AD_MULTI_CONTENT_URLS: ["https://www.google.com", "https://newsbreak.com"],
            MSPConstants.USE_NOVA_SANDBOX: novaSandbox ? "true" : "false",
        ]

        if let htmlTestAdString, !htmlTestAdString.isEmpty {
            customParams["nova_test_ad_string"] = htmlTestAdString
        }
        if let adConfig = applovinAdConfig(for: selectedPlacement) {
            customParams["msp_ad_config"] = adConfig
        }
        let adRequest = AdRequest(
            customParams: customParams,
            geo: nil,
            context: nil,
            adaptiveBannerSize: adSize,
            adSize: adSize,
            placementId: selectedPlacement,
            adFormat: format.mspFormat,
            testParams: params.toDictionary()
        )
        loader.loadAd(placementId: selectedPlacement, adListener: adListener, adRequest: adRequest)
    }

    func destroyAd() {
        adLoader = nil
        loadedBannerSize = CGSize(width: 320, height: 50)
        state = .idle
    }

    // MARK: - AppLovin Test Config

    private static let applovinTestPlacements: [String: String] = [
        "demoapp-ios-applovin-banner-test": "banner",
        "demoapp-ios-applovin-native-test": "native",
        "demoapp-ios-applovin-interstitial-test": "interstitial",
        "demoapp-ios-applovin-rewarded-test": "rewarded",
    ]

    private func applovinAdConfig(for placement: String) -> String? {
        guard let format = Self.applovinTestPlacements[placement] else { return nil }
        return """
            {"placement_id":"\(placement)","auction_timeout":8000,"bidders":[{"name":"applovin","bidder_placement_id":"YOUR_AD_UNIT_ID","bidder_format":"\(format)"}]}
            """
    }

    // MARK: - AdListener callback handlers (called by VC on main thread)

    func handleAdLoaded(placementId: String) {
        guard let ad = adLoader?.getAd(placementId: placementId) else {
            state = .error("getAd returned nil for \(placementId)")
            return
        }
        state = .loaded(ad)
    }

    func handleAdLoaded(ad: MSPAd) {
        if case .loading = state { state = .loaded(ad) }
    }

    func handleAdShowing(ad: MSPAd) {
        state = .showing(ad)
    }

    func handleAdDismissed() {
        state = .idle
    }

    func handleAdError(_ msg: String) {
        state = .error(msg)
    }
}
