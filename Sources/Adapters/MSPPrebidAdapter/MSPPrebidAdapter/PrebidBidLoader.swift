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

        // Dump the outbound bid-request context so future "no bid" investigations can
        // confirm what the SDK actually told Prebid Server about this slot — placement
        // identity, ad_format, video capabilities, custom params. Server-side recall
        // mismatches almost always show up first as a discrepancy between this and the
        // server's expected slot config.
        let videoParams = adUnitConfig.adConfiguration.videoParameters
        MSPLogger.shared.info(
            message:
                "[PrebidBidLoader] Outbound bid request. configId=\(self.configId ?? "nil"), adFormat=\(adRequest.adFormat), placementId=\(adRequest.placementId), context=\(adUnitConfig.contextDataDictionary), customParams=\(adRequest.customParams), videoMimes=\(String(describing: videoParams.mimes)), videoProtocols=\(String(describing: videoParams.protocols)), videoPlaybackMethod=\(String(describing: videoParams.playbackMethod)), videoPlacement=\(String(describing: videoParams.placement))"
        )

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
                // Enumerate every seatbid in the response — not just the winning seat —
                // so future investigations can distinguish "server never recalled bidder
                // X" from "X bid but lost the auction" from "X bid and won". The default
                // "Winning bid received" log only surfaces the winner, which masks the
                // first two cases entirely.
                if let raw = bidResponse.rawResponseInJson,
                    let seatbids = raw["seatbid"] as? [[String: Any]]
                {
                    let seatSummary = seatbids.map { sb -> String in
                        let seat = (sb["seat"] as? String) ?? "<no seat>"
                        let bids = (sb["bid"] as? [[String: Any]]) ?? []
                        let prices = bids.compactMap { $0["price"] as? Double }.map { String($0) }.joined(separator: ",")
                        return "\(seat)[\(bids.count) bid(s), prices=\(prices)]"
                    }.joined(separator: " | ")
                    MSPLogger.shared.info(
                        message:
                            "[PrebidBidLoader] Response seatbids. placementId=\(self.configId ?? "nil"), seatCount=\(seatbids.count), seats=\(seatSummary)"
                    )
                } else {
                    MSPLogger.shared.info(
                        message:
                            "[PrebidBidLoader] Response has no seatbid array. placementId=\(self.configId ?? "nil"), rawResponseInJson keys=\(bidResponse.rawResponseInJson?.allKeys ?? [])"
                    )
                }

                guard let seat = bidResponse.winningBidSeat else {
                    let errorMessage = "no fill"
                    MSPLogger.shared.info(
                        message:
                            "[PrebidBidLoader] No winning bid (no fill). placementId=\(self.configId ?? "nil"), requestId=\(bidResponse.rawResponse?.requestID ?? "nil")"
                    )
                    bidListener?.onError(msg: errorMessage, loadInfo: buildLoadInfo(bidResponse: bidResponse))
                    adMetricReporter?.logAdResponse(
                        ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_NO_FILL, errorMessage: errorMessage,
                        bidResponse: bidResponse)
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
                    ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_NETWORK_ERROR, errorMessage: errorMessage,
                    bidResponse: bidResponse)
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

        if adRequest.adFormat == .rewarded {
            // Three-layer placement contract (see spec FR-017a/b/c):
            //   * `placement` — publisher-supplied placementId, passthrough. SDK does not
            //     synthesize or validate it.
            //   * `ad_format` — fixed `rewarded_video` enum when AdRequest.adFormat == .rewarded.
            //     Distinct request field from `placement`.
            //   * Ad Server internal `ctx.placementName == "REWARDED_VIDEO"` — derived
            //     server-side via SSP config (ad_unit → REWARDED_VIDEO) per the MON
            //     Nova Rewarded Ad Tech Design. This is what Phase 1 routing / recall /
            //     filter / template-selection key off.
            //
            // Open verification (FR-017c): the Tech Design traces `ctx.placementName` to
            // SSP lookup only. SDK does NOT intend to influence it through this contextData
            // `placement` value (which is the publisher placementId, not "REWARDED_VIDEO").
            // If a future Ad Server fallback path also reads the OpenRTB
            // `imp[].ext.context.data.placement` field — pending request-log verification —
            // FR-017a passthrough behavior may conflict with FR-017c, and this site would
            // need revisiting.
            //
            // Note: Phase 1 Ad Server does NOT read `ad_format` for routing. It is written
            // here for (a) MES `ad_impression` / `ad_click` event compatibility (those
            // events stamp `ad_format` metadata) and (b) the future H5 Template Engine
            // Redesign that will key off `{placement}_{creative_type}` AB pairs. Do not
            // remove as dead code — see spec FR-017b. Order: set after custom params so
            // callers cannot accidentally downgrade `ad_format` to the SDK-internal "rewarded".
            adUnitConfig.removeContextData(for: "ad_format")
            adUnitConfig.addContextData(key: "ad_format", value: MSPConstants.AD_FORMAT_REWARDED_VIDEO)
            adUnitConfig.removeContextData(for: "placement")
            adUnitConfig.addContextData(key: "placement", value: adRequest.placementId)
        }

        var testParams = adRequest.testParams
        let inNovaTestMode =
            testParams["test_ad"] as? Bool == true
            && testParams["ad_network"] as? String == "msp_nova"

        // Nova test/debug routing on the server relies on TWO independent fields in
        // imp.ext.context.data:
        //   - `debug_item` — present only in Nova test mode; carries
        //     creative_type / h5_template_group / etc. so the server's debug recall
        //     path returns the requested creative shape (including PLAYABLE_VIDEO).
        //   - `test`      — ALWAYS sent. Carries `{"ad_network": ..., "test_ad": ...}`
        //     so the server knows which adapter is being targeted and whether to
        //     enter the test/debug branch.
        //
        // Earlier this method emitted them mutually exclusively (debug_item replaced
        // test in Nova test mode). That worked for interstitial because production
        // waterfall has inventory, but rewarded Phase 1 has no production fill (the
        // server's REWARDED_VIDEO recall path is gated by SSP mapping), so without
        // `test` the server never enters the debug branch and `debug_item` is
        // silently dropped — observed as 0% fill for rewarded playable. Android
        // emits both fields; this aligns with that.
        if inNovaTestMode,
            let debugItem = testParams[MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM] as? [String: Any],
            let debugItemJSON = toJSONString(debugItem)
        {
            adUnitConfig.removeContextData(for: MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM)
            adUnitConfig.addContextData(key: MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM, value: debugItemJSON)
        }
        // Strip debug_item from the `test` payload so the two fields don't carry
        // the same data, then always emit `test`.
        testParams.removeValue(forKey: MSPConstants.TEST_PARAM_KEY_DEBUG_ITEM)
        if let testParamsJSON = toJSONString(testParams) {
            let testKey = "test"
            adUnitConfig.removeContextData(for: testKey)
            adUnitConfig.addContextData(key: testKey, value: testParamsJSON)
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
        // Advertise both sound-on and sound-off autoplay support. The OpenRTB
        // `playbackMethod` field is a slot-capability declaration that ad serving
        // uses for inventory matching — restricting it to sound-on filters out
        // Nova rewarded creatives whose `playbackmethod` is configured as muted
        // autoplay, which silently kills server-side Nova rewarded recall.
        // PRD's `is_mute = false` is an H5-runtime player setting (see PRD
        // Clarifications session 2026-04-29: the video player runs entirely
        // inside the H5), not an OpenRTB-level request signal — keep these
        // layers separate.
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
