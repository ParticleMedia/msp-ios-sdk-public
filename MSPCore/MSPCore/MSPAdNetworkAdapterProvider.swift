//
//  MSPAdNetworkAdapterProvider.swift
//  MSPUtility
//
//  Created by Huanzhi Zhang on 1/9/24.
//

import Foundation
import PrebidAdapter
import MSPiOSCore



public class MSPAdNetworkAdapterProvider: AdNetworkAdapterProvider {
    public func getAdNetworkAdaptersCount() -> Int {
        return 2
    }
    
    public var rootViewController: UIViewController?
    
    public var googleManager: AdNetworkManager?
    
    
    public init() {
        
    }
    
    public func getAdNetworkAdapter(adNetwork: AdNetwork) -> AdNetworkAdapter? {
        print("msp begin get adnetwork adapter")
        let myAdNetworkName = adNetwork
        if adNetwork == .prebid {
            var prebidAdLoader = PrebidAdLoader()
            prebidAdLoader.rootViewController = self.rootViewController
           
            return prebidAdLoader
        } else if adNetwork ==  .google {
            var gadAdLoader = googleManager?.getAdNetworkAdapter()
            //gadAdLoader.rootViewController = self.rootViewController
            return gadAdLoader
        }
        return nil
    }
}

public class AdNetworkAdapterStandalone: AdNetworkAdapter {
    public func loadAdCreative(bidResponse: Any, adListener: any MSPiOSCore.AdListener, context: Any, adRequest: MSPiOSCore.AdRequest) {
        
    }
    
    public func initialize(initParams: MSPiOSCore.InitializationParameters, adapterInitListener: any MSPiOSCore.AdapterInitListener, context: Any?) {
        
    }
    
    public func destroyAd() {
        
    }
}
