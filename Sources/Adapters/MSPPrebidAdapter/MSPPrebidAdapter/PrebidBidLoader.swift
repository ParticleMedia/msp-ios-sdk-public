//import shared
import Foundation
import MSPiOSCore
import PrebidMobile

public class PrebidBidLoader: BidLoader {
    public var bidRequester: PBMBidRequester?
    public var configId: String?
    public weak var bidListener: BidListener?

    public var adRequest: AdRequest?

    public var googleQueryInfo: String?
    public var facebookBidToken: String?
    public var molocoBidToken: String?
    public var liftoffBidToken: String?
    private let dispatchGroup = DispatchGroup()
    public var adMetricReporter: AdMetricReporter?

    private var fetchTokensStartTime: TimeInterval = 0
    private var googleTokenCompletionTime: TimeInterval = 0
    private var facebookTokenCompletionTime: TimeInterval = 0
    private var molocoTokenCompletionTime: TimeInterval = 0
    private var liftoffTokenCompletionTime: TimeInterval = 0

    public override init(tokenProviders: BidTokenProviders) {
        super.init(tokenProviders: tokenProviders)
    }

    public override func loadBid(
        placementId: String, adParams: [String: Any], bidListener: any BidListener, adRequest: AdRequest
    ) {
        self.configId = placementId
        self.bidListener = bidListener
        self.adRequest = adRequest

        self.fetchTokens(adRequest: adRequest) { [weak self] bidTokens in
            guard let self = self else {
                return
            }
            self.loadBidWithTokens(bidTokens: bidTokens, adRequest: adRequest)
        }
    }

    func fetchTokens(adRequest: AdRequest, completion: @escaping (BidTokens) -> Void) {
        fetchTokensStartTime = Date().timeIntervalSince1970

        self.dispatchGroup.enter()
        self.googleQueryInfoFetcher.fetch(completeListener: self, adRequest: adRequest)

        self.dispatchGroup.enter()
        self.facebookBidTokenProvider.fetch(completeListener: self, context: self)

        self.dispatchGroup.enter()
        self.molocoBidTokenProvider.fetch(completeListener: self, context: self)

        self.dispatchGroup.enter()
        self.liftoffBidTokenProvider.fetch(completeListener: self, context: self)

        dispatchGroup.notify(queue: .main) {
            let bidTokens = BidTokens()
                .with(googleQueryInfo: self.googleQueryInfo)
                .with(facebookBidToken: self.facebookBidToken)
                .with(molocoBidToken: self.molocoBidToken)
                .with(liftoffBidToken: self.liftoffBidToken)
            let start = self.fetchTokensStartTime
            adRequest.s2sLatencyInfo.bidTokenLatency = [
                "google": Int32((self.googleTokenCompletionTime - start) * 1000),
                "facebook": Int32((self.facebookTokenCompletionTime - start) * 1000),
                "moloco": Int32((self.molocoTokenCompletionTime - start) * 1000),
                "liftoff": Int32((self.liftoffTokenCompletionTime - start) * 1000),
            ]
            completion(bidTokens)
        }
    }

    public func loadBidWithTokens(bidTokens: BidTokens, adRequest: AdRequest) {
        let width = Int(adRequest.adSize?.width ?? 320)
        let height = Int(adRequest.adSize?.height ?? 50)
        let adSize = CGSize(width: width, height: height)
        let adUnitConfig = getAdUnitConfig(
            configId: configId ?? "demo-ios-article-top",
            bidTokens: bidTokens,
            requestUUID: adRequest.requestId,
            prebidBannerAdSize: adSize,
            adRequest: adRequest)

        let bidRequester = PBMBidRequester(
            connection: ServerConnection.shared,
            sdkConfiguration: Prebid.shared,
            targeting: Targeting.shared,
            adUnitConfiguration: adUnitConfig)
        self.bidRequester = bidRequester

        let bidRequestStartTime = Date().timeIntervalSince1970
        bidRequester.requestBids { [weak self] bidResponse, error in
            guard let self = self else { return }
            adRequest.s2sLatencyInfo.bidRequestLatencyMs = Int32(
                (Date().timeIntervalSince1970 - bidRequestStartTime) * 1000)

            if let error = error {
                MSPLogger.shared.error(
                    message:
                        "[PrebidBidLoader] Bid request failed. placementId=\(self.configId ?? "nil"), error=\(error.localizedDescription)"
                )
                bidListener?.onError(msg: error.localizedDescription, loadInfo: [:])
                return
            }

            if let bidResponse = bidResponse {
                guard let seat = bidResponse.winningBidSeat else {
                    let errorMessage = "no fill"
                    MSPLogger.shared.info(
                        message:
                            "[PrebidBidLoader] No winning bid (no fill). placementId=\(self.configId ?? "nil"), requestId=\(bidResponse.rawResponse?.requestID ?? "nil")"
                    )
                    bidListener?.onError(msg: errorMessage, loadInfo: buildLoadInfo(bidResponse: bidResponse))
                    adMetricReporter?.logAdResponse(
                        ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_NO_FILL, errorMessage: errorMessage)
                    return
                }

                let price = bidResponse.winningBid?.price ?? 0
                MSPLogger.shared.info(
                    message:
                        "[PrebidBidLoader] Winning bid received. placementId=\(self.configId ?? "nil"), seat=\(seat), price=\(price), adFormat=\(adRequest.adFormat), requestId=\(bidResponse.rawResponse?.requestID ?? "nil")"
                )

                if self.bidListener == nil {
                    MSPLogger.shared.error(
                        message:
                            "[PrebidBidLoader] bidListener is nil — cannot route bid. placementId=\(self.configId ?? "nil"), seat=\(seat)"
                    )
                }
                if seat == "msp_google" {
                    self.bidListener?.onBidResponse(bidResponse: bidResponse, adNetwork: AdNetwork.google)
                } else if seat == "audienceNetwork" {
                    self.bidListener?.onBidResponse(bidResponse: bidResponse, adNetwork: AdNetwork.facebook)
                } else if seat == "msp_nova" {
                    self.bidListener?.onBidResponse(bidResponse: bidResponse, adNetwork: AdNetwork.nova)
                } else if seat == "msp_moloco" {
                    self.bidListener?.onBidResponse(bidResponse: bidResponse, adNetwork: AdNetwork.moloco)
                } else if seat == "vungle" {
                    self.bidListener?.onBidResponse(bidResponse: bidResponse, adNetwork: AdNetwork.liftoff)
                } else {
                    MSPLogger.shared.info(
                        message:
                            "[PrebidBidLoader] Unknown seat '\(seat)', routing to prebid adapter. placementId=\(self.configId ?? "nil")"
                    )
                    self.bidListener?.onBidResponse(bidResponse: bidResponse, adNetwork: AdNetwork.prebid)
                }
            } else {
                let errorMessage = "missing response"
                MSPLogger.shared.error(
                    message: "[PrebidBidLoader] Missing response. placementId=\(self.configId ?? "nil")")
                bidListener?.onError(msg: errorMessage, loadInfo: buildLoadInfo(bidResponse: bidResponse))
                adMetricReporter?.logAdResponse(
                    ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_NETWORK_ERROR, errorMessage: errorMessage)
            }
        }
    }


    public func getAdUnitConfig(
        configId: String,
        bidTokens: BidTokens,
        requestUUID: String,
        prebidBannerAdSize: CGSize,
        adRequest: AdRequest
    ) -> AdUnitConfig {
        let usesSizedAdUnit = !(adRequest.adFormat == .interstitial || adRequest.adFormat == .rewarded)
        let adUnitConfig =
            usesSizedAdUnit == false
            ? AdUnitConfig(configId: configId) : AdUnitConfig(configId: configId, size: prebidBannerAdSize)
        if adRequest.adFormat == .banner {
            adUnitConfig.adConfiguration.bannerParameters.api = PrebidConstants.supportedRenderingBannerAPISignals
            adUnitConfig.adFormats = [.display]
        } else if adRequest.adFormat == .native {
            adUnitConfig.nativeAdConfiguration = NativeAdConfiguration()
            adUnitConfig.adFormats = [.native]
        } else if adRequest.adFormat == .multi_format {
            adUnitConfig.adConfiguration.bannerParameters.api = PrebidConstants.supportedRenderingBannerAPISignals
            adUnitConfig.nativeAdConfiguration = NativeAdConfiguration()
            adUnitConfig.adFormats = [.display, .native]
        } else if adRequest.adFormat == .interstitial {
            adUnitConfig.adPosition = .fullScreen
            adUnitConfig.adConfiguration.adFormats = [.display]
            adUnitConfig.adConfiguration.isInterstitialAd = true
            adUnitConfig.adConfiguration.bannerParameters.api = PrebidConstants.supportedRenderingBannerAPISignals
        } else if adRequest.adFormat == .rewarded {
            adUnitConfig.adConfiguration.adFormats = [.video]
            adUnitConfig.adConfiguration.isOptIn = true
            adUnitConfig.adConfiguration.videoParameters = buildRewardedVideoParameters()
        }

        var userExt = Targeting.shared.userExt ?? [String: AnyHashable]()
        userExt["geo"] = getGeoDict()
        Targeting.shared.userExt = userExt

        if let userId = UserDefaults.standard.string(forKey: MSPConstants.USER_DEFAULTS_KEY_MSP_USER_ID) {
            adUnitConfig.addContextData(key: MSPConstants.USER_ID, value: userId)
        }

        let customParams = adRequest.customParams
        for (key, value) in customParams where value is String {
            adUnitConfig.removeContextData(for: key)
            adUnitConfig.addContextData(key: key, value: value as? String ?? "")
            if key == MSPConstants.USER_ID,
                let appUserId = value as? String
            {
                // override user id in bid context and local cache with provided in the ad request
                UserDefaults.standard.setValue(appUserId, forKey: MSPConstants.USER_DEFAULTS_KEY_MSP_USER_ID)
            }
        }

        var testParams = adRequest.testParams
        let inNovaTestMode =
            testParams["test_ad"] as? Bool == true
            && testParams["ad_network"] as? String == "msp_nova"
        if inNovaTestMode,
            let debugItem = testParams[MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM] as? [String: Any],
            let debugItemJSON = toJSONString(debugItem)
        {
            adUnitConfig.removeContextData(for: MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM)
            adUnitConfig.addContextData(key: MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM, value: debugItemJSON)
        } else {
            testParams.removeValue(forKey: MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM)
            if let testParamsJSON = toJSONString(testParams) {
                let testKey = "test"
                adUnitConfig.removeContextData(for: testKey)
                adUnitConfig.addContextData(key: testKey, value: testParamsJSON)
            }
        }

        if let gadQueryInfo = bidTokens.googleQueryInfo {
            adUnitConfig.addContextData(key: "query_info", value: gadQueryInfo)
        }
        if let facebookBidToken = bidTokens.facebookBidToken {
            Targeting.shared.buyerUID = facebookBidToken
        }
        if let molocoBidToken = bidTokens.molocoBidToken {
            adUnitConfig.addContextData(key: "moloco_bid_token", value: molocoBidToken)
        }
        if let liftoffBidToken = bidTokens.liftoffBidToken {
            adUnitConfig.addContextData(key: "liftoff_bid_token", value: liftoffBidToken)
        }

        if adRequest.adFormat == .native || adRequest.adFormat == .multi_format {
            var assets: [NativeAsset] = []
            assets.append(NativeAssetTitle(length: 100, required: true))
            adUnitConfig.nativeAdConfiguration?.markupRequestObject.assets = assets
        }

        return adUnitConfig
    }

    private func buildRewardedVideoParameters() -> VideoParameters {
        let parameters = VideoParameters()
        parameters.mimes = ["video/mp4"]
        parameters.protocols = [.VAST_2_0, .VAST_3_0, .VAST_4_0]
        parameters.playbackMethod = [.AutoPlaySoundOn, .AutoPlaySoundOff]
        parameters.placement = .Interstitial
        return parameters
    }

    private func toJSONString(_ dict: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(dict) else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func getGeoDict() -> [String: String] {
        var geoDict: [String: String] = [:]
        geoDict["city"] = adRequest?.geo?.city
        geoDict["state_code"] = adRequest?.geo?.stateCode
        geoDict["zipcode"] = adRequest?.geo?.zipCode
        geoDict["lat"] = adRequest?.geo?.lat
        geoDict["lon"] = adRequest?.geo?.lon
        return geoDict
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

extension PrebidBidLoader: GoogleQueryInfoListener {
    public func onComplete(queryInfo: String) {
        self.googleQueryInfo = queryInfo
        googleTokenCompletionTime = Date().timeIntervalSince1970
        dispatchGroup.leave()
    }
}

extension PrebidBidLoader: FacebookBidTokenListener {
    public func onComplete(bidToken: String) {
        self.facebookBidToken = bidToken
        facebookTokenCompletionTime = Date().timeIntervalSince1970
        dispatchGroup.leave()
    }
}

extension PrebidBidLoader: MolocoBidTokenListener {
    public func onComplete(molocoBidToken: String) {
        self.molocoBidToken = molocoBidToken
        molocoTokenCompletionTime = Date().timeIntervalSince1970
        dispatchGroup.leave()
    }
}

extension PrebidBidLoader: LiftoffBidTokenListener {
    public func onComplete(liftoffBidToken: String) {
        self.liftoffBidToken = liftoffBidToken
        liftoffTokenCompletionTime = Date().timeIntervalSince1970
        dispatchGroup.leave()
    }
}
