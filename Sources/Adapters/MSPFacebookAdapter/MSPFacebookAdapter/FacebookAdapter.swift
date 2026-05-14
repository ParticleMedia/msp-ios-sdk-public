//import shared
import AppTrackingTransparency
import FBAudienceNetwork
import Foundation
import MSPiOSCore
import PrebidMobile
import UIKit

@objc public class FacebookAdapter: NSObject, AdNetworkAdapter {
    public func getSDKVersion() -> String {
        FB_AD_SDK_VERSION
    }

    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }

    @MainActor
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        guard let nativeAdView = nativeAdView as? NativeAdView,
            let mediaView = nativeAd.mediaView as? FBMediaView,
            let fbNativeAdItem = self.nativeAdItem
        else { return }
        //let fbNativeAdView = UIView()
        nativeAdView.translatesAutoresizingMaskIntoConstraints = false
        if let nativeAdContainer = nativeAdView.nativeAdContainer {
            nativeAdContainer.translatesAutoresizingMaskIntoConstraints = false

            nativeAdView.addSubview(nativeAdContainer)

            if let mediaContainer = nativeAdContainer.getMedia() {
                mediaContainer.addSubview(mediaView)
                NSLayoutConstraint.activate([
                    //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                    mediaView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
                    mediaView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
                    mediaView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
                    mediaView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor),
                ])
            }

            if let iconView = nativeAdContainer.getIcon(),
                let image = fbNativeAdItem.iconImage
            {
                //gadNativeAdView.iconView = iconView
                iconView.image = image
            }

            NSLayoutConstraint.activate([
                //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
                nativeAdContainer.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
                nativeAdContainer.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
                nativeAdContainer.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
                nativeAdContainer.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
                nativeAdContainer.widthAnchor.constraint(lessThanOrEqualTo: nativeAdView.widthAnchor),
                nativeAdContainer.heightAnchor.constraint(lessThanOrEqualTo: nativeAdView.heightAnchor),
            ])

            let fbSubViews = [
                nativeAdContainer.getTitle(), nativeAdContainer.getbody(), nativeAdContainer.getAdvertiser(),
                nativeAdContainer.getCallToAction(), nativeAdContainer.getIcon(), mediaView,
            ]
            fbNativeAdItem.registerView(
                forInteraction: nativeAdView,
                mediaView: mediaView,
                iconImageView: nativeAdContainer.getIcon(),
                viewController: nil,
                clickableViews: fbSubViews.compactMap { $0 })
        }

        let fbAdOptionsView = FBAdOptionsView(frame: .zero)
        fbAdOptionsView.backgroundColor = .clear
        fbAdOptionsView.translatesAutoresizingMaskIntoConstraints = false

        nativeAdView.addSubview(fbAdOptionsView)
        NSLayoutConstraint.activate([
            fbAdOptionsView.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
            fbAdOptionsView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            fbAdOptionsView.widthAnchor.constraint(equalToConstant: FBAdOptionsViewWidth),
            fbAdOptionsView.heightAnchor.constraint(equalToConstant: FBAdOptionsViewHeight),
        ])
        fbAdOptionsView.nativeAd = fbNativeAdItem
    }

    public weak var adListener: AdListener?
    public var priceInDollar: Double?

    private var nativeAdItem: FBNativeAd?
    private weak var facebookNativeAd: FacebookNativeAd?
    private var adRequest: AdRequest?
    private var bidResponse: BidResponse?

    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?

    private weak var facebookInterstitialAd: FacebookInterstitialAd?
    private var interstitialAdItem: FBInterstitialAd?
    private var facebookRewardedAd: FacebookRewardedAd?
    private var rewardedVideoAdItem: FBRewardedVideoAd?

    private var adMetricReporter: AdMetricReporter?
    private var adLoadStartTime: TimeInterval = 0

    public func destroyAd() {
    }

    public func initialize(
        initParams: any InitializationParameters, adapterInitListener: any AdapterInitListener, context: Any?
    ) {
        FBAdSettings.setAdvertiserTrackingEnabled(isIDFAAuthorized())
        FBAudienceNetworkAds.initialize(
            with: nil,
            completionHandler: { _ in
                adapterInitListener.onComplete(adNetwork: .facebook, adapterInitStatus: .SUCCESS, message: "")
            })
    }

    public func loadAdCreative(
        bidResponse: Any, auctionBidListener: AuctionBidListener, adListener: any AdListener, context: Any,
        adRequest: AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?, params: [String: String]?
    ) {
        adLoadStartTime = Date().timeIntervalSince1970
        DispatchQueue.main.async {
            self.adListener = adListener
            self.adRequest = adRequest
            self.auctionBidListener = auctionBidListener
            self.bidderPlacementId = bidderPlacementId

            guard bidResponse is BidResponse,
                let mBidResponse = bidResponse as? BidResponse
            else {
                self.handleAuctionBidError(error: "no valid response")
                return
            }

            self.bidResponse = mBidResponse

            guard let adString = mBidResponse.winningBid?.bid.adm else {
                self.handleAuctionBidError(error: "no valid response", bidResponse: mBidResponse)
                return
            }

            self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0)

            switch adRequest.adFormat {
            case .native:
                guard let placementId = self.getFBPlacementId(from: adString) else {
                    self.handleAuctionBidError(error: "Missing FB payload or placementId", bidResponse: mBidResponse)
                    return
                }
                self.nativeAdItem = FBNativeAd(placementID: placementId)
                self.nativeAdItem?.delegate = self
                self.nativeAdItem?.loadAd(withBidPayload: adString)

            case .banner:
                guard let placementId = self.getFBPlacementId(from: adString) else {
                    self.handleAuctionBidError(error: "Missing FB payload or placementId", bidResponse: mBidResponse)
                    return
                }
                self.nativeAdItem = FBNativeAd(placementID: placementId)
                self.nativeAdItem?.delegate = self
                self.nativeAdItem?.loadAd(withBidPayload: adString)

            case .interstitial:
                guard let placementId = self.getFBPlacementId(from: adString) else {
                    self.handleAuctionBidError(
                        error: "Missing FB payload or placementId", bidResponse: mBidResponse)
                    return
                }
                let facebookInterstitialAdItem = FBInterstitialAd(placementID: placementId)
                self.interstitialAdItem = facebookInterstitialAdItem
                facebookInterstitialAdItem.delegate = self
                facebookInterstitialAdItem.load(withBidPayload: adString)

            case .rewarded:
                guard let placementId = self.getFBPlacementId(from: adString) else {
                    self.handleAuctionBidError(
                        error: "Missing FB payload or placementId", bidResponse: mBidResponse)
                    return
                }
                MSPLogger.shared.info(
                    message:
                        "[Adapter: Facebook] Loading Rewarded ad. placementId=\(adRequest.placementId), fbPlacementId=\(placementId), requestId=\(mBidResponse.rawResponse?.requestID ?? "nil")"
                )
                let rewardedVideoAdItem = FBRewardedVideoAd(placementID: placementId)
                self.rewardedVideoAdItem = rewardedVideoAdItem
                let facebookRewardedAd = FacebookRewardedAd(
                    adNetworkAdapter: self,
                    reward: adRequest.reward,
                    rewardedVideoAdItem: rewardedVideoAdItem,
                    rootViewController: self.adListener?.getRootViewController(),
                    adListener: self.adListener
                )
                self.facebookRewardedAd = facebookRewardedAd
                rewardedVideoAdItem.delegate = self
                rewardedVideoAdItem.load(withBidPayload: adString)

            case .multi_format:
                let rawBidDict = self.SafeAs(mBidResponse.winningBid?.bid.rawJsonDictionary, [String: Any].self)
                let bidExtDict = self.SafeAs(rawBidDict?["ext"], [String: Any].self)
                let prebidExtDict = self.SafeAs(bidExtDict?["prebid"], [String: Any].self)
                let adType = self.SafeAs(prebidExtDict?["type"], String.self)

                switch adType {
                case "banner":
                    guard let placementId = self.getFBPlacementId(from: adString) else {
                        self.handleAuctionBidError(
                            error: "Missing FB payload or placementId", bidResponse: mBidResponse)
                        return
                    }
                    self.nativeAdItem = FBNativeAd(placementID: placementId)
                    self.nativeAdItem?.delegate = self
                    self.nativeAdItem?.loadAd(withBidPayload: adString)
                case "native":
                    guard let placementId = self.getFBPlacementId(from: adString) else {
                        self.handleAuctionBidError(
                            error: "Missing FB payload or placementId", bidResponse: mBidResponse)
                        return
                    }
                    self.nativeAdItem = FBNativeAd(placementID: placementId)
                    self.nativeAdItem?.delegate = self
                    self.nativeAdItem?.loadAd(withBidPayload: adString)
                default:
                    self.handleAuctionBidError(
                        error: "Unsupported adType: \(adType ?? "nil") for multi_format", bidResponse: mBidResponse)
                }

            default:
                self.handleAuctionBidError(
                    error: "Unsupported adFormat: \(adRequest.adFormat)", bidResponse: mBidResponse)
            }
        }
    }

    public func loadTestAdCreative() {
        nativeAdItem = FBNativeAd(placementID: "placementId#IMG_16_9_LINK")
        nativeAdItem?.delegate = self

        self.nativeAdItem?.loadAd(withBidPayload: "placementId#IMG_16_9_LINK")
    }

    public func isIDFAAuthorized() -> Bool {
        if #available(iOS 14, *), case .authorized = ATTrackingManager.trackingAuthorizationStatus {
            return true
        } else {
            return false
        }
    }

    private func SafeAs<T, U>(_ object: T?, _ objectType: U.Type) -> U? {
        if let object = object {
            if let temp = object as? U {
                return temp
            } else {
                return nil
            }
        } else {
            // It's always OK to cast nil to nil
            return nil
        }
    }

    private func getFBPlacementId(from payload: String) -> String? {
        guard let data = payload.data(using: .utf8) else {
            self.handleAuctionBidError(error: "Failed to get data from FB payload", bidResponse: self.bidResponse)
            return nil
        }

        do {
            guard let dict = SafeAs(try JSONSerialization.jsonObject(with: data), [String: Any].self) else {
                self.handleAuctionBidError(
                    error: "Failed to convert FB payload to json dict", bidResponse: self.bidResponse)
                return nil
            }
            return SafeAs(dict["resolved_placement_id"], String.self)
        } catch {
            self.handleAuctionBidError(
                error: "Failed to json serialize FB payload, error = \(error.localizedDescription)",
                bidResponse: self.bidResponse)
            return nil
        }
    }

    public func handleAdLoaded(ad: MSPAd, auctionBidListener: AuctionBidListener, bidderPlacementId: String) {
        adRequest?.s2sLatencyInfo.adLoadLatencyMs = Int32((Date().timeIntervalSince1970 - adLoadStartTime) * 1000)
        // to do: move this to ios core
        AdCache.shared.saveAd(placementId: bidderPlacementId, ad: ad)
        let auctionBid = AuctionBid(
            bidderName: "msp",
            bidderPlacementId: bidderPlacementId,
            ecpm: ad.adInfo["price"] as? Double ?? 0.0,
            loadInfo: buildLoadInfo(bidResponse: self.bidResponse))
        auctionBid.ad = ad
        auctionBidListener.onSuccess(bid: auctionBid)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(
                ad: ad, adRequest: adRequest, errorCode: .ERROR_CODE_SUCCESS, errorMessage: nil,
                bidResponse: self.bidResponse)
        }
    }

    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        .facebook
    }

    public func getAdRequest() -> AdRequest? { adRequest }

    public func getAdMetricReporter() -> AdMetricReporter? { adMetricReporter }

    public func getBidResponse() -> Any? { bidResponse }

    public func sendHideAdEvent(reason: String, adScreenShot: Data?, fullScreenShot: Data?) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest,
                let ad = (self.facebookNativeAd ?? self.facebookInterstitialAd) ?? self.facebookRewardedAd
            {
                self.adMetricReporter?.logAdHide(
                    ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, adScreenShot: adScreenShot,
                    fullScreenShot: fullScreenShot)
            }
        }
    }

    public func sendDismissAdEvent() {
        if let adRequest = self.adRequest,
            let ad = self.facebookInterstitialAd ?? self.facebookRewardedAd
        {
            self.adMetricReporter?.logAdDismiss(ad: ad, adRequest: adRequest, bidResponse: self.bidResponse ?? self)
        }
    }

    public func sendReportAdEvent(reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest,
                let ad = (self.facebookNativeAd ?? self.facebookInterstitialAd) ?? self.facebookRewardedAd
            {
                self.adMetricReporter?.logAdReport(
                    ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, description: description,
                    adScreenShot: adScreenShot, fullScreenShot: fullScreenShot)
            }
        }
    }

    private func sendClickAdEvent(ad: MSPAd) {
        DispatchQueue.main.async {
            if let adRequest = self.adRequest,
                let bidResponse = self.bidResponse
            {
                self.adMetricReporter?.logAdClick(ad: ad, adRequest: adRequest, bidResponse: bidResponse)
            }
        }
    }

    private func handleAuctionBidError(error: String, bidResponse: BidResponse? = nil) {
        guard let auctionBidListener = self.auctionBidListener else { return }

        if let bidResponse = bidResponse {
            let requestId = bidResponse.rawResponse?.requestID ?? ""
            auctionBidListener.onError(error: error, loadInfo: buildLoadInfo(bidResponse: bidResponse))
        } else {
            auctionBidListener.onError(error: error)
        }
    }

    private func buildLoadInfo(bidResponse: BidResponse?) -> [String: Any] {
        var loadInfo: [String: Any] = [:]

        if let requestId = bidResponse?.rawResponse?.requestID,
            !requestId.isEmpty
        {
            loadInfo["request_id"] = requestId
        }

        return loadInfo
    }
}


extension FacebookAdapter: FBNativeAdDelegate {
    public func nativeAdDidLoad(_ nativeAd: FBNativeAd) {
        MSPLogger.shared.info(message: "[Adapter: Facebook] successfully loaded Facebook Native ad")
        DispatchQueue.main.async {
            let mediaView = FBMediaView(frame: .zero)
            mediaView.translatesAutoresizingMaskIntoConstraints = false

            let facebookNativeAd = FacebookNativeAd(
                adNetworkAdapter: self,
                title: nativeAd.headline ?? "",
                body: nativeAd.bodyText ?? "",
                advertiser: nativeAd.advertiserName ?? "",
                callToAction: nativeAd.callToAction ?? "")
            self.facebookNativeAd = facebookNativeAd
            facebookNativeAd.priceInDollar = self.priceInDollar
            facebookNativeAd.nativeAdItem = nativeAd
            facebookNativeAd.mediaView = mediaView
            facebookNativeAd.icon = nativeAd.iconImage
            facebookNativeAd.adInfo[MSPConstants.AD_INFO_PRICE] = self.priceInDollar
            facebookNativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.facebook.rawValue
            facebookNativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = nativeAd.placementID
            facebookNativeAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] = self.bidResponse?.winningBid?.bid.crid
            if let requestId = self.bidResponse?.rawResponse?.requestID {
                facebookNativeAd.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] = requestId
            }
            self.nativeAdItem = nativeAd
            if let adListener = self.adListener,
                let adRequest = self.adRequest,
                let auctionBidListener = self.auctionBidListener
            {
                //handleAdLoaded(ad: facebookNativeAd, listener: adListener, adRequest: adRequest)
                self.handleAdLoaded(
                    ad: facebookNativeAd, auctionBidListener: auctionBidListener,
                    bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)
            }
        }
    }

    public func nativeAd(_ nativeAd: FBNativeAd, didFailWithError error: Error) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(message: "[Adapter: Facebook] Fail to load Facebook Native ad")
            self.handleAuctionBidError(error: error.localizedDescription, bidResponse: self.bidResponse)
            if let adRequest = self.adRequest {
                self.adMetricReporter?.logAdResponse(
                    ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR,
                    errorMessage: error.localizedDescription, bidResponse: self.bidResponse)
            }
        }
    }

    public func nativeAdWillLogImpression(_ nativeAd: FBNativeAd) {
        DispatchQueue.main.async {
            if let facebookNativeAd = self.facebookNativeAd {
                if let adRequest = self.adRequest,
                    let bidResponse = self.bidResponse
                {
                    self.adMetricReporter?.logAdImpression(
                        ad: facebookNativeAd, adRequest: adRequest, bidResponse: bidResponse)
                }
                self.adListener?.onAdImpression(ad: facebookNativeAd)
            }
        }
    }

    public func nativeAdDidClick(_ nativeAd: FBNativeAd) {
        if let facebookNativeAd = self.facebookNativeAd {
            self.adListener?.onAdClick(ad: facebookNativeAd)
            self.sendClickAdEvent(ad: facebookNativeAd)
        }
    }
}

extension FacebookAdapter: FBInterstitialAdDelegate {
    public func interstitialAdDidLoad(_ interstitialAd: FBInterstitialAd) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(message: "[Adapter: Facebook] successfully loaded Facebook Interstitial ad")
            var facebookInterstitialAd = FacebookInterstitialAd(adNetworkAdapter: self)
            facebookInterstitialAd.interstitialAdItem = interstitialAd
            interstitialAd.delegate = self
            self.interstitialAdItem = interstitialAd
            self.facebookInterstitialAd = facebookInterstitialAd
            if let priceInDollar = self.priceInDollar {
                facebookInterstitialAd.adInfo[MSPConstants.AD_INFO_PRICE] = priceInDollar
            }
            facebookInterstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.facebook.rawValue
            facebookInterstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = interstitialAd.placementID
            facebookInterstitialAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] =
                self.bidResponse?.winningBid?.bid.crid
            if let requestId = self.bidResponse?.rawResponse?.requestID {
                facebookInterstitialAd.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] = requestId
            }

            if let adListener = self.adListener,
                let adRequest = self.adRequest,
                let auctionBidListener = self.auctionBidListener
            {
                //handleAdLoaded(ad: facebookInterstitialAd, listener: adListener, adRequest: adRequest)
                self.handleAdLoaded(
                    ad: facebookInterstitialAd, auctionBidListener: auctionBidListener,
                    bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)
                self.adMetricReporter?.logAdResult(
                    placementId: adRequest.placementId, ad: facebookInterstitialAd, fill: true, isFromCache: false)
            }
        }
    }

    public func interstitialAd(_ interstitialAd: FBInterstitialAd, didFailWithError error: Error) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(message: "[Adapter: Facebook] Fail to load Facebook Interstitial ad")
            self.handleAuctionBidError(error: error.localizedDescription)
            self.adMetricReporter?.logAdResult(
                placementId: self.adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
            if let adRequest = self.adRequest {
                self.adMetricReporter?.logAdResponse(
                    ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR,
                    errorMessage: error.localizedDescription, bidResponse: self.bidResponse)
            }
        }
    }

    public func interstitialAdDidClick(_ interstitialAd: FBInterstitialAd) {
        if let facebookInterstitialAd = self.facebookInterstitialAd {
            self.adListener?.onAdClick(ad: facebookInterstitialAd)
            self.sendClickAdEvent(ad: facebookInterstitialAd)
        }
    }

    public func interstitialAdDidClose(_ interstitialAd: FBInterstitialAd) {
        if let facebookInterstitialAd = self.facebookInterstitialAd {
            self.adListener?.onAdDismissed(ad: facebookInterstitialAd)
            self.sendDismissAdEvent()
        }
    }

    public func interstitialAdWillLogImpression(_ interstitialAd: FBInterstitialAd) {
        DispatchQueue.main.async {
            if let facebookInterstitialAd = self.facebookInterstitialAd {
                if let adRequest = self.adRequest,
                    let bidResponse = self.bidResponse
                {
                    self.adMetricReporter?.logAdImpression(
                        ad: facebookInterstitialAd, adRequest: adRequest, bidResponse: bidResponse)
                }
                self.adListener?.onAdImpression(ad: facebookInterstitialAd)
            }
        }
    }
}

extension FacebookAdapter: FBRewardedVideoAdDelegate {
    public func rewardedVideoAdDidLoad(_ rewardedVideoAd: FBRewardedVideoAd) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(
                message:
                    "[Adapter: Facebook] successfully loaded Facebook Rewarded ad. placementId=\(self.adRequest?.placementId ?? "nil"), adUnitId=\(rewardedVideoAd.placementID), requestId=\(self.bidResponse?.rawResponse?.requestID ?? "nil"), reward=\(self.adRequest?.reward?.type ?? "nil"):\(self.adRequest?.reward?.amount.description ?? "nil")"
            )
            guard let facebookRewardedAd = self.facebookRewardedAd,
                let adRequest = self.adRequest,
                let auctionBidListener = self.auctionBidListener
            else {
                MSPLogger.shared.error(
                    message:
                        "[Adapter: Facebook] GUARD FAILED in rewardedVideoAdDidLoad — facebookRewardedAd=\(self.facebookRewardedAd != nil), adRequest=\(self.adRequest != nil), auctionBidListener=\(self.auctionBidListener != nil)"
                )
                return
            }

            if let priceInDollar = self.priceInDollar {
                facebookRewardedAd.adInfo[MSPConstants.AD_INFO_PRICE] = priceInDollar
            }
            facebookRewardedAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.facebook.rawValue
            facebookRewardedAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = rewardedVideoAd.placementID
            facebookRewardedAd.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] =
                self.bidResponse?.winningBid?.bid.crid
            if let requestId = self.bidResponse?.rawResponse?.requestID {
                facebookRewardedAd.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] = requestId
            }

            self.handleAdLoaded(
                ad: facebookRewardedAd,
                auctionBidListener: auctionBidListener,
                bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId
            )
            self.adMetricReporter?.logAdResult(
                placementId: adRequest.placementId, ad: facebookRewardedAd, fill: true, isFromCache: false)
        }
    }

    public func rewardedVideoAd(_ rewardedVideoAd: FBRewardedVideoAd, didFailWithError error: Error) {
        DispatchQueue.main.async {
            MSPLogger.shared.error(
                message:
                    "[Adapter: Facebook] Fail to load Facebook Rewarded ad. placementId=\(self.adRequest?.placementId ?? "nil"), adUnitId=\(rewardedVideoAd.placementID), requestId=\(self.bidResponse?.rawResponse?.requestID ?? "nil"), error=\(error.localizedDescription)"
            )
            self.handleAuctionBidError(error: error.localizedDescription, bidResponse: self.bidResponse)
            self.adMetricReporter?.logAdResult(
                placementId: self.adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
        }
    }

    public func rewardedVideoAdWillLogImpression(_ rewardedVideoAd: FBRewardedVideoAd) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(
                message:
                    "[Adapter: Facebook] Rewarded impression callback. placementId=\(self.adRequest?.placementId ?? "nil"), adUnitId=\(rewardedVideoAd.placementID), requestId=\(self.bidResponse?.rawResponse?.requestID ?? "nil")"
            )
            self.facebookRewardedAd?.markDisplayed()
        }
    }

    public func rewardedVideoAdDidClick(_ rewardedVideoAd: FBRewardedVideoAd) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(
                message:
                    "[Adapter: Facebook] Rewarded click callback. placementId=\(self.adRequest?.placementId ?? "nil"), adUnitId=\(rewardedVideoAd.placementID), requestId=\(self.bidResponse?.rawResponse?.requestID ?? "nil")"
            )
            // Keep post-centralization (commit 010388a8) form: markClicked is the single
            // source of truth for adListener.onAdClick + MES dispatch. Restoring the
            // develop-side direct calls would reintroduce the double-fire bug that
            // RewardedLifecycleController was created to prevent.
            self.facebookRewardedAd?.markClicked()
        }
    }

    public func rewardedVideoAdVideoComplete(_ rewardedVideoAd: FBRewardedVideoAd) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(
                message:
                    "[Adapter: Facebook] Rewarded completion callback. placementId=\(self.adRequest?.placementId ?? "nil"), adUnitId=\(rewardedVideoAd.placementID), requestId=\(self.bidResponse?.rawResponse?.requestID ?? "nil")"
            )
            self.facebookRewardedAd?.markRewardEarned()
        }
    }

    public func rewardedVideoAdDidClose(_ rewardedVideoAd: FBRewardedVideoAd) {
        DispatchQueue.main.async {
            MSPLogger.shared.info(
                message:
                    "[Adapter: Facebook] Rewarded close callback. placementId=\(self.adRequest?.placementId ?? "nil"), adUnitId=\(rewardedVideoAd.placementID), requestId=\(self.bidResponse?.rawResponse?.requestID ?? "nil")"
            )
            self.facebookRewardedAd?.markDismissed()
            self.sendDismissAdEvent()
        }
    }
}
