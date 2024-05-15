//
//  PrebidBidLoader.swift
//  PrebidAdapter
//
//  Created by Huanzhi Zhang on 12/19/23.
//

import Foundation
//import shared
import MSPiOSCore
import PrebidMobile

public class PrebidBidLoader : BidLoader {
    
    public var bidRequester: PBMBidRequester?
    public var configId: String?
    public var bidListener: BidListener?
    
    public var adRequest: AdRequest?
    
    public override init(googleQueryInfoFetcher: GoogleQueryInfoFetcher, facebookBidTokenProvider: FacebookBidTokenProvider) {
        
        super.init(googleQueryInfoFetcher: googleQueryInfoFetcher, facebookBidTokenProvider: facebookBidTokenProvider)
        
        Prebid.shared.shareGeoLocation = true
    }
    
    public override func loadBid(placementId: String, adParams: [String : Any], bidListener: any BidListener, adRequest: AdRequest) {
        
        self.configId = placementId
        self.bidListener = bidListener
        self.adRequest = adRequest
        
        googleQueryInfoFetcher.fetch(completeListener: self, adRequest: adRequest)
    }
    
    public func loadBidWithQueryInfo(queryInfo: String) {
        print("msp start load bid with query info")
        let width = Int(adRequest?.adSize?.width ?? 320)
        let height = Int(adRequest?.adSize?.height ?? 50)
        let adSize = CGSize(width: width, height: height)
        var adUnitConfig = multiFormatAdUnitConfig(configId: configId ?? "msp-ios-article-top-display",
                                                   gadQueryInfo: queryInfo,
                                                   requestUUID: UUID().uuidString,
                                                   prebidBannerAdSize: adSize)
        
        let bidRequester = PBMBidRequester(connection: ServerConnection.shared,
                                           sdkConfiguration: Prebid.shared,
                                           targeting: Targeting.shared,
                                           adUnitConfiguration: adUnitConfig)
        self.bidRequester = bidRequester
        
        bidRequester.requestBids { [weak self] bidResponse, error in
            guard let self = self else { return }

            if let error = error {
                print("msp error:" + error.localizedDescription)
                bidListener?.onError(msg: error.localizedDescription)
                return
            }
            
            if let bidResponse = bidResponse {
                let seat = bidResponse.winningBidSeat
                if self.bidListener == nil {
                    print("msp missing bidListener")
                }
                if seat == "msp_google" {
                    print("msp receive google response")
                    self.bidListener?.onBidResponse(bidResponse: bidResponse, adNetwork: .google)
                } else {
                    print("msp receive prebid response")
                    self.bidListener?.onBidResponse(bidResponse: bidResponse, adNetwork: .prebid)
                }
            } else {
                bidListener?.onError(msg: "missing response")
            }
        }
    }
    
    
    public func multiFormatAdUnitConfig(configId: String,
                                               gadQueryInfo: String,
                                               requestUUID: String,
                                               prebidBannerAdSize: CGSize) -> AdUnitConfig {
        let adUnitConfig = AdUnitConfig(configId: configId, size: prebidBannerAdSize)
        adUnitConfig.adConfiguration.bannerParameters.api = PrebidConstants.supportedRenderingBannerAPISignals
        adUnitConfig.nativeAdConfiguration = NativeAdConfiguration()
        adUnitConfig.adFormats = [.display, .native]
        
        var userExt = Targeting.shared.userExt ?? [String: AnyHashable]()
        userExt["geo"] = getGeoDict()
        Targeting.shared.userExt = userExt
        
        if let customParams = adRequest?.customParams {
            for (key, value) in customParams {
                if value is String {
                    adUnitConfig.addContextData(key: key, value: value as? String ?? "")
                }
            }
        }

        
        adUnitConfig.addContextData(key: "query_info", value: gadQueryInfo)
        var assets = [NativeAsset]()
        assets.append(NativeAssetTitle(length: 100, required: true))
        adUnitConfig.nativeAdConfiguration?.markupRequestObject.assets = assets

        
        
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
        loadBidWithQueryInfo(queryInfo: queryInfo)
    }
}


