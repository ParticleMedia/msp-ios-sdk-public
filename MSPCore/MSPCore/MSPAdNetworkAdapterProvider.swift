//
//  MSPAdNetworkAdapterProvider.swift
//  MSPUtility
//
//  Created by Huanzhi Zhang on 1/9/24.
//

import Foundation
import PrebidAdapter
//import MSPiOSCore
import shared
import UIKit



public class MSPAdNetworkAdapterProvider: AdNetworkAdapterProvider {
    public func getAdNetworkAdaptersCount() -> Int32 {
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
        print("msp begin get adnetwork adapter")
        if adNetwork.name == "Prebid" {
            var prebidAdLoader = PrebidAdLoader()
            self.adNetworkAdapter = prebidAdLoader
            return prebidAdLoader
        } else if adNetwork.name == "Google" {
            var gadAdLoader = googleManager?.getAdNetworkAdapter()
            self.adNetworkAdapter = gadAdLoader
            return gadAdLoader
        } else if adNetwork.name == "Nova" {
            var novaAdLoader = novaManager?.getAdNetworkAdapter()
            self.adNetworkAdapter = novaAdLoader
            return novaAdLoader
        } else if adNetwork.name == "Facebook" {
            var metaAdapter = metaManager?.getAdNetworkAdapter()
            self.adNetworkAdapter = metaAdapter
            return metaAdapter
        }
        return nil
    }
    
    public func getAdNetworkAdapterByName(adNetworkName: String) -> AdNetworkAdapter? {
        print("msp begin get adnetwork adapter")
        if adNetworkName == "Prebid" {
            var prebidAdLoader = PrebidAdLoader()
            self.adNetworkAdapter = prebidAdLoader
            return prebidAdLoader
        } else if adNetworkName == "Google" {
            var gadAdLoader = googleManager?.getAdNetworkAdapter()
            self.adNetworkAdapter = gadAdLoader
            return gadAdLoader
        } else if adNetworkName == "Nova" {
            var novaAdLoader = novaManager?.getAdNetworkAdapter()
            self.adNetworkAdapter = novaAdLoader
            return novaAdLoader
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
