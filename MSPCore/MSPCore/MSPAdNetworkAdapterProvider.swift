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



public class MSPAdNetworkAdapterProvider: AdNetworkAdapterProvider {
    public func getAdNetworkAdaptersCount() -> Int32 {
        return 2
    }
    
    //public func getAdNetworkAdaptersCount() -> Int {
    //    return 2
    //}
    
    public var rootViewController: UIViewController?
    
    public var googleManager: AdNetworkManager?
    
    
    public init() {
        
    }
    
    public func getAdNetworkAdapter(adNetwork: AdNetwork) -> AdNetworkAdapter? {
        print("msp begin get adnetwork adapter")
        if adNetwork.name == AdNetwork.prebid.name {
            var prebidAdLoader = PrebidAdLoader()
            return prebidAdLoader
        } else if adNetwork.name == AdNetwork.google.name {
            var gadAdLoader = googleManager?.getAdNetworkAdapter()
            return gadAdLoader
        }
        return nil
    }
}

public class AdNetworkAdapterStandalone: AdNetworkAdapter {
    public func loadAdCreative(bidResponse: Any, adListener: AdListener, context: Any, adRequest: AdRequest) {
        
    }
    
    public func initialize(initParams: InitializationParameters, adapterInitListener: any AdapterInitListener, context: Any?) {
        
    }
    
    public func destroyAd() {
        
    }
}
