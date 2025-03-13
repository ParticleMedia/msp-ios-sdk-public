//
//  MSPAd.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/11/24.
//

open class MSPAd {
    
    public var adNetworkAdapter: AdNetworkAdapter?
    public var adInfo: [String: Any]
    public weak var adListener: AdListener?
    
    public init(adNetworkAdapter: AdNetworkAdapter) {
        self.adNetworkAdapter = adNetworkAdapter
        self.adInfo = [String: Any]()
    }
    

    public func destroy() {
        adNetworkAdapter?.destroyAd()
    }
}
