//
//  MSPAdNetworkAdapterProvider.swift
//  MSPUtility
//
//  Created by Huanzhi Zhang on 1/9/24.
//

import Foundation
import PrebidAdapter
import MSPiOSCore
// shared
import UIKit



public class MSPAdNetworkAdapterProvider: AdNetworkAdapterProvider {
    public func getAdNetworkAdaptersCount() -> Int {
        return adNetworkManagerDict.count
        /*
        let managers: [AdNetworkManager?] = [googleManager, metaManager, novaManager]
        var num = 1 //default vaule is 1 for prebid sdk is alwasys in the dependency
        for adManager in managers {
            if let manager = adManager {
                num += 1
            }
        }
        return num
         */
    }
    
    public var rootViewController: UIViewController?
    
    public var adNetworkManagerDict = [AdNetwork: AdNetworkManager]()
    
    public init() {
        
    }
    
    public func getAdNetworkAdapter(adNetwork: AdNetwork) -> AdNetworkAdapter? {
        if adNetwork == .prebid {
            return PrebidAdapter()
        }
        return adNetworkManagerDict[adNetwork]?.getAdNetworkAdapter()
    }
    
    public func getAdNetworkAdapterByName(adNetworkName: String) -> AdNetworkAdapter? {
        
        return nil
    }
}

public class AdNetworkAdapterStandalone: AdNetworkAdapter {
    public func getSDKVersion() -> String {
        return ""
    }
    
    public func sendHideAdEvent(reason: String, adScreenShot: Data?, fullScreenShot: Data?) {
        
    }
    
    public func sendReportAdEvent(reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?) {
        
    }
    
    public func loadAdCreative(bidResponse: Any, auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener, context: Any, adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?, params: [String: String]?) {
        
    }
    
    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        
    }
    
    public func prepareViewForInteraction(nativeAd: NativeAd, nativeAdView: Any) {
        
    }
    
    public func loadAdCreative(bidResponse: Any, auctionBidListener: AuctionBidListener, adListener: AdListener, context: Any, adRequest: AdRequest, bidderPlacementId: String) {
        
    }
    
    public func initialize(initParams: InitializationParameters, adapterInitListener: any AdapterInitListener, context: Any?) {
        
    }
    
    public func destroyAd() {
        
    }
    
    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        return .unknown
    }
}
