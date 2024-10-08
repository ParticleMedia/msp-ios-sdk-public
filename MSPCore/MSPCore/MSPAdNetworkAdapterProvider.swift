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
        let managers: [AdNetworkManager?] = [googleManager, metaManager, novaManager]
        var num = 1 //default vaule is 1 for prebid sdk is alwasys in the dependency
        for adManager in managers {
            if let manager = adManager {
                num += 1
            }
        }
        return num
    }
    
    public var rootViewController: UIViewController?
    
    public var googleManager: AdNetworkManager?
    
    public var novaManager: AdNetworkManager?
    
    public var metaManager: AdNetworkManager?
    
    public var adNetworkAdapter: AdNetworkAdapter?
    
    
    public init() {
        
    }
    
    public func getAdNetworkAdapter(adNetwork: AdNetwork) -> AdNetworkAdapter? {
        if adNetwork == .prebid {
            var prebidAdapter = PrebidAdapter()
            self.adNetworkAdapter = prebidAdapter
            return prebidAdapter
        } else if adNetwork == .google {
            var googleAdapter = googleManager?.getAdNetworkAdapter()
            self.adNetworkAdapter = googleAdapter
            return googleAdapter
        } else if adNetwork == .nova {
            var novaAdapter = novaManager?.getAdNetworkAdapter()
            self.adNetworkAdapter = novaAdapter
            return novaAdapter
        } else if adNetwork == .facebook {
            var facebookAdapter = metaManager?.getAdNetworkAdapter()
            self.adNetworkAdapter = facebookAdapter
            return facebookAdapter
        }
        return nil
    }
    
    public func getAdNetworkAdapterByName(adNetworkName: String) -> AdNetworkAdapter? {
        if adNetworkName == "Prebid" {
            var prebidAdapter = PrebidAdapter()
            self.adNetworkAdapter = prebidAdapter
            return prebidAdapter
        } else if adNetworkName == "Google" {
            var googleAdapter = googleManager?.getAdNetworkAdapter()
            self.adNetworkAdapter = googleAdapter
            return googleAdapter
        } else if adNetworkName == "Nova" {
            var novaAdapter = novaManager?.getAdNetworkAdapter()
            self.adNetworkAdapter = novaAdapter
            return novaAdapter
        } else if adNetworkName == "Facebook" {
            var facebookAdapter = metaManager?.getAdNetworkAdapter()
            self.adNetworkAdapter = facebookAdapter
            return facebookAdapter
        }
        return nil
    }
}

public class AdNetworkAdapterStandalone: AdNetworkAdapter {
    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        
    }
    
    public func prepareViewForInteraction(nativeAd: NativeAd, nativeAdView: Any) {
        
    }
    
    public func loadAdCreative(bidResponse: Any, adListener: AdListener, context: Any, adRequest: AdRequest) {
        
    }
    
    public func initialize(initParams: InitializationParameters, adapterInitListener: any AdapterInitListener, context: Any?) {
        
    }
    
    public func destroyAd() {
        
    }
}
