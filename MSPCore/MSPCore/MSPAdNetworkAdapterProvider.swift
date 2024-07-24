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
        return 2
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
            var prebidAdLoader = PrebidAdLoader()
            self.adNetworkAdapter = prebidAdLoader
            return prebidAdLoader
        } else if adNetwork == .google {
            var gadAdLoader = googleManager?.getAdNetworkAdapter()
            self.adNetworkAdapter = gadAdLoader
            return gadAdLoader
        } else if adNetwork == .nova {
            var novaAdapter = novaManager?.getAdNetworkAdapter()
            self.adNetworkAdapter = novaAdapter
            return novaAdapter
        } else if adNetwork == .facebook {
            var metaAdapter = metaManager?.getAdNetworkAdapter()
            self.adNetworkAdapter = metaAdapter
            return metaAdapter
        }
        return nil
    }
    
    public func getAdNetworkAdapterByName(adNetworkName: String) -> AdNetworkAdapter? {
        if adNetworkName == "Prebid" {
            var prebidAdLoader = PrebidAdLoader()
            self.adNetworkAdapter = prebidAdLoader
            return prebidAdLoader
        } else if adNetworkName == "Google" {
            var gadAdLoader = googleManager?.getAdNetworkAdapter()
            self.adNetworkAdapter = gadAdLoader
            return gadAdLoader
        } else if adNetworkName == "Nova" {
            var novaAdapter = novaManager?.getAdNetworkAdapter()
            self.adNetworkAdapter = novaAdapter
            return novaAdapter
        } else if adNetworkName == "Facebook" {
            var metaAdapter = metaManager?.getAdNetworkAdapter()
            self.adNetworkAdapter = metaAdapter
            return metaAdapter
        }
        return nil
    }
}

public class AdNetworkAdapterStandalone: AdNetworkAdapter {
    public func prepareViewForInteraction(nativeAd: NativeAd, nativeAdView: Any) {
        
    }
    
    public func loadAdCreative(bidResponse: Any, adListener: AdListener, context: Any, adRequest: AdRequest) {
        
    }
    
    public func initialize(initParams: InitializationParameters, adapterInitListener: any AdapterInitListener, context: Any?) {
        
    }
    
    public func destroyAd() {
        
    }
}
