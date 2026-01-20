import Foundation
//import shared
import MSPiOSCore
import PrebidMobile

public class PrebidBidLoader : BidLoader {
    
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
    
    public override init(tokenProviders: BidTokenProviders) {
        super.init(tokenProviders: tokenProviders)
    }
    
    public override func loadBid(placementId: String, adParams: [String : Any], bidListener: any BidListener, adRequest: AdRequest) {
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
            completion(bidTokens)
        }
    }
    
    public func loadBidWithTokens(bidTokens: BidTokens, adRequest: AdRequest) {
        let width = Int(adRequest.adSize?.width ?? 320)
        let height = Int(adRequest.adSize?.height ?? 50)
        let adSize = CGSize(width: width, height: height)
        let adUnitConfig = getAdUnitConfig(configId: configId ?? "demo-ios-article-top",
                                           bidTokens: bidTokens,
                                           requestUUID: adRequest.requestId,
                                           prebidBannerAdSize: adSize,
                                           adRequest: adRequest)
        
        let bidRequester = PBMBidRequester(connection: ServerConnection.shared,
                                           sdkConfiguration: Prebid.shared,
                                           targeting: Targeting.shared,
                                           adUnitConfiguration: adUnitConfig)
        self.bidRequester = bidRequester
        
        bidRequester.requestBids { [weak self] bidResponse, error in
            guard let self = self else { return }

            if let error = error {
                bidListener?.onError(msg: error.localizedDescription)
                return
            }
            
            if let bidResponse = bidResponse {
                guard let seat = bidResponse.winningBidSeat else {
                    let errorMessage = "no fill"
                    bidListener?.onError(msg: errorMessage)
                    adMetricReporter?.logAdResponse(ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_NO_FILL, errorMessage: errorMessage)
                    return
                }
                if self.bidListener == nil {
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
                    self.bidListener?.onBidResponse(bidResponse: bidResponse, adNetwork: AdNetwork.prebid)
                }
            } else {
                let errorMessage = "missing response"
                bidListener?.onError(msg: errorMessage)
                adMetricReporter?.logAdResponse(ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_NETWORK_ERROR, errorMessage: errorMessage)
            }
        }
    }
    
    
    public func getAdUnitConfig(configId: String,
                                bidTokens: BidTokens,
                                requestUUID: String,
                                prebidBannerAdSize: CGSize,
                                adRequest: AdRequest) -> AdUnitConfig {
        
        let adUnitConfig = adRequest.adFormat == .interstitial ?
        AdUnitConfig(configId: configId) :
        AdUnitConfig(configId: configId, size: prebidBannerAdSize)
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
        }
        
        var userExt = Targeting.shared.userExt ?? [String: AnyHashable]()
        userExt["geo"] = getGeoDict()
        Targeting.shared.userExt = userExt
        
        if let userId = UserDefaults.standard.string(forKey: MSPConstants.USER_DEFAULTS_KEY_MSP_USER_ID) {
            adUnitConfig.addContextData(key: MSPConstants.USER_ID, value: userId)
        }
        
        let customParams = adRequest.customParams
        for (key, value) in customParams {
            if value is String {
                adUnitConfig.removeContextData(for: key)
                adUnitConfig.addContextData(key: key, value: value as? String ?? "")
                if key == MSPConstants.USER_ID,
                   let appUserId = value as? String {
                    // override user id in bid context and local cache with provided in the ad request
                    UserDefaults.standard.setValue(appUserId, forKey: MSPConstants.USER_DEFAULTS_KEY_MSP_USER_ID)
                }
            }
        }
        
        
        let testParams = adRequest.testParams
        for (key, value) in testParams {
            if value is String {
                adUnitConfig.removeContextData(for: key)
                adUnitConfig.addContextData(key: key, value: value as? String ?? "")
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
            var assets = [NativeAsset]()
            assets.append(NativeAssetTitle(length: 100, required: true))
            adUnitConfig.nativeAdConfiguration?.markupRequestObject.assets = assets
        }
        
        return adUnitConfig
    }
    
    private func getGeoDict() -> [String: String] {
        var geoDict = [String: String]()
        geoDict["city"] = adRequest?.geo?.city
        geoDict["state_code"] = adRequest?.geo?.stateCode
        geoDict["zipcode"] = adRequest?.geo?.zipCode
        geoDict["lat"] = adRequest?.geo?.lat
        geoDict["lon"] = adRequest?.geo?.lon
        return geoDict
    }
}

extension PrebidBidLoader: GoogleQueryInfoListener {
    public func onComplete(queryInfo: String) {
        //loadBidWithQueryInfo(queryInfo: queryInfo)
        self.googleQueryInfo = queryInfo
        dispatchGroup.leave()
    }
}

extension PrebidBidLoader: FacebookBidTokenListener {
    public func onComplete(bidToken: String) {
        self.facebookBidToken = bidToken
        dispatchGroup.leave()
    }
}

extension PrebidBidLoader: MolocoBidTokenListener {
    public func onComplete(molocoBidToken: String) {
        self.molocoBidToken = molocoBidToken
        dispatchGroup.leave()
    }
}

extension PrebidBidLoader: LiftoffBidTokenListener {
    public func onComplete(liftoffBidToken: String) {
        self.liftoffBidToken = liftoffBidToken
        dispatchGroup.leave()
    }
}
