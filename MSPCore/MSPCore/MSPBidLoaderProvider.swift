//
//  MSPBidLoaderProvider.swift
//  MSPUtility
//
//  Created by Huanzhi Zhang on 1/9/24.
//

import Foundation
import PrebidAdapter
import MSPiOSCore
//import shared

public class MSPBidLoaderProvider: BidLoaderProvider {
    public var googleQueryInfoFetcher: GoogleQueryInfoFetcher?
    public var facebookBidTokenProvider: FacebookBidTokenProvider?
    public weak var bidLoader: BidLoader?
    
    public init() {
        
    }
    
    public func getBidLoader() -> BidLoader {
        let bidLoader = PrebidBidLoader(googleQueryInfoFetcher: googleQueryInfoFetcher ?? GoogleQueryInfoFetcherStandalone(), facebookBidTokenProvider: facebookBidTokenProvider ?? FacebookBidTokenProviderStandalone())
        self.bidLoader = bidLoader
        return bidLoader
    }
}

public class GoogleQueryInfoFetcherStandalone: GoogleQueryInfoFetcher {
    
    public func fetch(completeListener: GoogleQueryInfoListener, adRequest: AdRequest) {
        completeListener.onComplete(queryInfo: "dummy query info")
    } 
}

public class FacebookBidTokenProviderStandalone: FacebookBidTokenProvider {
    public func fetch(completeListener: any FacebookBidTokenListener, context: Any) {
        completeListener.onComplete(bidToken: "dummy bidder token")
    } 
}
