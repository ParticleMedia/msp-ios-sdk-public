//
//  ApplovinMaxAdapter.swift
//  ApplovinMaxAdapter
//

import AppLovinSDK
import Foundation
@_implementationOnly import MSPSnapKit
import MSPiOSCore
import UIKit

@objc public class ApplovinMaxAdapter: NSObject, AdNetworkAdapter {
    public weak var adListener: AdListener?
    public var adRequest: AdRequest?
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?

    private var adMetricReporter: AdMetricReporter?

    var bannerAdView: MAAdView?
    var interstitialAd: MAInterstitialAd?
    var maxRewardedAd: MARewardedAd?
    var nativeAdLoader: MANativeAdLoader?
    var loadedNativeAd: MAAd?

    private var bannerDelegateHandler: ApplovinMaxBannerDelegateHandler?
    private var nativeDelegateHandler: ApplovinMaxNativeDelegateHandler?
    private var interstitialDelegateHandler: ApplovinMaxInterstitialDelegateHandler?
    private var rewardedDelegateHandler: ApplovinMaxRewardedDelegateHandler?

    weak var mspBannerAd: BannerAd?
    weak var mspInterstitialAd: ApplovinMaxInterstitialAd?
    weak var mspNativeAd: ApplovinMaxNativeAd?
    weak var mspRewardedAd: ApplovinMaxRewardedAd?

    var crid: String?
    var priceInDollar: Double?

    public func getSDKVersion() -> String {
        ALSdk.version()
    }

    public func loadAdCreative(
        bidResponse: Any, auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener,
        context: Any, adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?,
        params: [String: String]?
    ) {
        self.auctionBidListener = auctionBidListener
        self.adListener = adListener
        self.adRequest = adRequest
        self.bidderPlacementId = bidderPlacementId

        let adFormat = bidderFormat ?? adRequest.adFormat

        MSPLogger.shared.info(
            message:
                "[Adapter: ApplovinMax] Start to load ApplovinMax creative ad. AdFormat = \(adFormat), placementId = \(bidderPlacementId)"
        )

        switch adFormat {
        case .interstitial:
            loadInterstitialAd(bidderPlacementId: bidderPlacementId)
        case .native, .multi_format:
            loadNativeAd(bidderPlacementId: bidderPlacementId)
        case .rewarded:
            loadRewardedAdIfSupported(
                bidResponse: bidResponse,
                auctionBidListener: auctionBidListener,
                adListener: adListener,
                context: context,
                adRequest: adRequest,
                bidderPlacementId: bidderPlacementId,
                params: params
            )
        case .banner:
            loadBannerAd(bidderPlacementId: bidderPlacementId, adSize: adRequest.adSize)
        default:
            handleAdLoadFailed(error: "Unsupported ad format: \(adFormat)")
        }
    }

    private func loadInterstitialAd(bidderPlacementId: String) {
        MSPLogger.shared.info(
            message: "[Adapter: ApplovinMax] Loading interstitial ad, adUnitId = \(bidderPlacementId)")
        let interstitial = MAInterstitialAd(adUnitIdentifier: bidderPlacementId)
        let handler = ApplovinMaxInterstitialDelegateHandler(adapter: self)
        interstitialDelegateHandler = handler
        interstitial.delegate = handler
        self.interstitialAd = interstitial
        interstitial.load()
    }

    private func loadNativeAd(bidderPlacementId: String) {
        MSPLogger.shared.info(
            message: "[Adapter: ApplovinMax] Loading native ad, adUnitId = \(bidderPlacementId)")
        let loader = MANativeAdLoader(adUnitIdentifier: bidderPlacementId)
        let handler = ApplovinMaxNativeDelegateHandler(adapter: self)
        nativeDelegateHandler = handler
        loader.nativeAdDelegate = handler
        loader.revenueDelegate = handler
        self.nativeAdLoader = loader
        loader.loadAd()
    }

    private func loadBannerAd(bidderPlacementId: String, adSize: AdSize?) {
        MSPLogger.shared.info(
            message:
                "[Adapter: ApplovinMax] Loading banner ad, adUnitId = \(bidderPlacementId), adSize = \(adSize?.width ?? 0)x\(adSize?.height ?? 0)"
        )
        let adView = MAAdView(
            adUnitIdentifier: bidderPlacementId, adFormat: maxBannerFormat(from: adSize))
        let handler = ApplovinMaxBannerDelegateHandler(adapter: self)
        bannerDelegateHandler = handler
        adView.delegate = handler
        self.bannerAdView = adView
        adView.loadAd()
    }

    public func loadRewardedAdIfSupported(
        bidResponse: Any,
        auctionBidListener: AuctionBidListener,
        adListener: AdListener,
        context: Any,
        adRequest: AdRequest,
        bidderPlacementId: String,
        params: [String: String]?
    ) {
        MSPLogger.shared.info(
            message: "[Adapter: ApplovinMax] Loading rewarded ad, adUnitId = \(bidderPlacementId)")
        let rewarded = MARewardedAd.shared(withAdUnitIdentifier: bidderPlacementId)
        let handler = ApplovinMaxRewardedDelegateHandler(adapter: self)
        rewardedDelegateHandler = handler
        rewarded.delegate = handler
        self.maxRewardedAd = rewarded
        rewarded.load()
    }

    public func initialize(
        initParams: any MSPiOSCore.InitializationParameters, adapterInitListener: any MSPiOSCore.AdapterInitListener,
        context: Any?
    ) {
        if let params = initParams.getParameters(),
            let sdkKey = params[InitializationParametersCustomKeys.APPLOVIN_SDK_KEY] as? String
        {
            let initConfig = ALSdkInitializationConfiguration(sdkKey: sdkKey) { builder in
                builder.mediationProvider = ALMediationProviderMAX
                #if DEBUG || BETA
                    if let currentIDFV = UIDevice.current.identifierForVendor?.uuidString {
                        builder.testDeviceAdvertisingIdentifiers = [currentIDFV]
                    }
                #endif
            }
            #if DEBUG || BETA
                ALSdk.shared().settings.isVerboseLoggingEnabled = true
            #endif
            ALSdk.shared().initialize(with: initConfig) { _ in
                MSPLogger.shared.info(message: "[Adapter: AppLovinMax] adapter initialized successfully")
                adapterInitListener.onComplete(adNetwork: .applovin, adapterInitStatus: .SUCCESS, message: "")
            }
        } else {
            MSPLogger.shared.info(message: "[Adapter: AppLovinMax] failed to initialze adapter, sdkKey is empty")
            adapterInitListener.onComplete(adNetwork: .applovin, adapterInitStatus: .SUCCESS, message: "")
        }
    }

    public func destroyAd() {
        bannerAdView?.delegate = nil
        bannerAdView = nil
        bannerDelegateHandler = nil
        interstitialAd?.delegate = nil
        interstitialAd = nil
        interstitialDelegateHandler = nil
        maxRewardedAd?.delegate = nil
        maxRewardedAd = nil
        rewardedDelegateHandler = nil
        if let loadedNativeAd = loadedNativeAd {
            nativeAdLoader?.destroy(loadedNativeAd)
        }
        nativeAdLoader?.nativeAdDelegate = nil
        nativeAdLoader?.revenueDelegate = nil
        nativeAdLoader = nil
        nativeDelegateHandler = nil
        loadedNativeAd = nil
    }

    @MainActor
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        guard let mspNativeAdView = nativeAdView as? NativeAdView else {
            MSPLogger.shared.debug(
                tag: "Native",
                message:
                    "[Adapter: ApplovinMax] prepareViewForInteraction: nativeAdView is not a NativeAdView, got \(type(of: nativeAdView))"
            )
            return
        }
        guard let applovinNativeAd = nativeAd as? ApplovinMaxNativeAd else {
            MSPLogger.shared.debug(
                tag: "Native",
                message:
                    "[Adapter: ApplovinMax] prepareViewForInteraction: nativeAd is not an ApplovinMaxNativeAd, got \(type(of: nativeAd))"
            )
            return
        }
        guard let loadedAd = applovinNativeAd.loadedAd else {
            MSPLogger.shared.debug(
                tag: "Native",
                message:
                    "[Adapter: ApplovinMax] prepareViewForInteraction: loadedAd is nil"
            )
            return
        }
        guard let nativeAdLoader = self.nativeAdLoader else {
            MSPLogger.shared.debug(
                tag: "Native",
                message:
                    "[Adapter: ApplovinMax] prepareViewForInteraction: nativeAdLoader is nil"
            )
            return
        }

        guard let nativeAdContainer = mspNativeAdView.nativeAdContainer else {
            MSPLogger.shared.debug(
                tag: "Native",
                message:
                    "[Adapter: ApplovinMax] prepareViewForInteraction: nativeAdContainer is nil"
            )
            return
        }
        nativeAdContainer.translatesAutoresizingMaskIntoConstraints = false

        let maxNativeAdView = MANativeAdView()
        maxNativeAdView.translatesAutoresizingMaskIntoConstraints = false

        maxNativeAdView.titleLabel = nativeAdContainer.getTitle()
        maxNativeAdView.bodyLabel = nativeAdContainer.getbody()
        maxNativeAdView.advertiserLabel = nativeAdContainer.getAdvertiser()
        maxNativeAdView.callToActionButton = nativeAdContainer.getCallToAction()
        maxNativeAdView.iconImageView = nativeAdContainer.getIcon()
        maxNativeAdView.mediaContentView = nativeAdContainer.getMedia()

        maxNativeAdView.addSubview(nativeAdContainer)
        nativeAdContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        nativeAdLoader.renderNativeAdView(maxNativeAdView, with: loadedAd)

        nativeAdContainer.getTitle()?.text = nativeAd.title
        nativeAdContainer.getbody()?.text = nativeAd.body
        nativeAdContainer.getAdvertiser()?.text = nativeAd.advertiser
        nativeAdContainer.getCallToAction()?.setTitle(nativeAd.callToAction, for: .normal)
        nativeAdContainer.getCallToAction()?.isUserInteractionEnabled = false

        mspNativeAdView.addSubview(maxNativeAdView)
        maxNativeAdView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }

    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        .applovin
    }

    public func sendHideAdEvent(reason: String, adScreenShot: Data?, fullScreenShot: Data?) {
        if let adRequest = self.adRequest,
            let ad = ((self.mspBannerAd ?? self.mspNativeAd) ?? self.mspInterstitialAd) ?? self.mspRewardedAd
        {
            self.adMetricReporter?.logAdHide(
                ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, adScreenShot: adScreenShot,
                fullScreenShot: fullScreenShot)
        }
    }

    public func sendReportAdEvent(reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?) {
        if let adRequest = self.adRequest,
            let ad = ((self.mspBannerAd ?? self.mspNativeAd) ?? self.mspInterstitialAd) ?? self.mspRewardedAd
        {
            self.adMetricReporter?.logAdReport(
                ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, description: description,
                adScreenShot: adScreenShot, fullScreenShot: fullScreenShot)
        }
    }

    // MARK: - Private

    private func maxBannerFormat(from adSize: AdSize?) -> MAAdFormat {
        guard let adSize = adSize else { return .banner }
        if adSize.width == 300, adSize.height == 250 {
            return .mrec
        }
        return .banner
    }

    func handleAdLoaded(mspAd: MSPAd) {
        guard let auctionBidListener = self.auctionBidListener,
            let bidderPlacementId = self.bidderPlacementId
        else { return }

        #if DEBUG
            if let price = self.priceInDollar, price == 0 {
                MSPLogger.shared.info(
                    message:
                        "[Adapter: ApplovinMax] DEBUG: ad.revenue is 0 (test ad), overriding to 0.5 to avoid being filtered"
                )
                self.priceInDollar = 0.5
            }
        #endif

        mspAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar
        mspAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.applovin.rawValue
        mspAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = bidderPlacementId
        if let crid = self.crid {
            mspAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = crid
        }

        AdCache.shared.saveAd(placementId: bidderPlacementId, ad: mspAd)
        let auctionBid = AuctionBid(
            bidderName: AdNetwork.applovin.rawValue,
            bidderPlacementId: bidderPlacementId,
            ecpm: mspAd.adInfo[MSPConstants.AD_INFO_PRICE] as? Double ?? 0.0,
            loadInfo: [:])
        auctionBid.ad = mspAd
        auctionBidListener.onSuccess(bid: auctionBid)

        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(
                ad: mspAd, adRequest: adRequest, errorCode: .ERROR_CODE_SUCCESS, errorMessage: nil)
        }

        self.adMetricReporter?.logAdResult(
            placementId: adRequest?.placementId ?? "",
            ad: mspAd,
            fill: true,
            isFromCache: false
        )
    }

    func handleAdLoadFailed(error: String) {
        MSPLogger.shared.info(message: "[Adapter: ApplovinMax] Failed to load ad: \(error)")
        self.auctionBidListener?.onError(error: error)

        self.adMetricReporter?.logAdResult(
            placementId: adRequest?.placementId ?? "",
            ad: nil,
            fill: false,
            isFromCache: false
        )

        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(
                ad: nil,
                adRequest: adRequest,
                errorCode: .ERROR_CODE_INTERNAL_ERROR,
                errorMessage: error
            )
        }
    }

    func handleAdImpression(mspAd: MSPAd) {
        MSPLogger.shared.info(message: "[Adapter: ApplovinMax] Show ApplovinMax ad successfully")
        self.adListener?.onAdImpression(ad: mspAd)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdImpression(ad: mspAd, adRequest: adRequest, bidResponse: self)
        }
    }

    func handleAdClicked(mspAd: MSPAd) {
        MSPLogger.shared.info(message: "[Adapter: ApplovinMax] ApplovinMax ad clicked")
        self.adListener?.onAdClick(ad: mspAd)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdClick(ad: mspAd, adRequest: adRequest, bidResponse: self)
        }
    }
}
