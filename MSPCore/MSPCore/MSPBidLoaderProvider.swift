//
//  MSPBidLoaderProvider.swift
//  MSPUtility
//
//  Created by Huanzhi Zhang on 1/9/24.
//

import Foundation
import PrebidAdapter
import MSPiOSCore

public class MSPBidLoaderProvider: BidLoaderProvider {
    public var googleQueryInfoFetcher: GoogleQueryInfoFetcher?
    
    public init() {
        
    }
    
    public func getBidLoader() -> BidLoader {
        print("msp get bid load without google query info fetcher")
        return PrebidBidLoader(googleQueryInfoFetcher: googleQueryInfoFetcher ?? GoogleQueryInfoFetcherStandalone(), facebookBidTokenProvider: FacebookBidTokenProviderStandalone())
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
