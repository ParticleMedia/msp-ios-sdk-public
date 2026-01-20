//
//  BidLoader.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/12/24.
//

import Foundation


open class BidLoader {
    public var googleQueryInfoFetcher: GoogleQueryInfoFetcher
    public var facebookBidTokenProvider: FacebookBidTokenProvider
    public var molocoBidTokenProvider: MolocoBidTokenProvider
    public var liftoffBidTokenProvider: LiftoffBidTokenProvider

    public init(tokenProviders: BidTokenProviders) {
        // Unwrap with default dummy implementations to maintain non-optional properties
        self.googleQueryInfoFetcher = tokenProviders.googleQueryInfoFetcher ?? GoogleQueryInfoFetcherStandalone()
        self.facebookBidTokenProvider = tokenProviders.facebookBidTokenProvider ?? FacebookBidTokenProviderStandalone()
        self.molocoBidTokenProvider = tokenProviders.molocoBidTokenProvider ?? MolocoBidTokenProviderStandalone()
        self.liftoffBidTokenProvider = tokenProviders.liftoffBidTokenProvider ?? LiftoffBidTokenProviderStandalone()
    }

    open func loadBid(placementId: String, adParams: [String: Any], bidListener: BidListener, adRequest: AdRequest) {

    }
}

// MARK: - Dummy Implementations
public class GoogleQueryInfoFetcherStandalone: GoogleQueryInfoFetcher {
    
    public init() {}
    
    public func fetch(completeListener: GoogleQueryInfoListener, adRequest: AdRequest) {
        completeListener.onComplete(queryInfo: "dummy query info")
    }
}

public class FacebookBidTokenProviderStandalone: FacebookBidTokenProvider {
    
    public init() {}
    
    public func fetch(completeListener: any FacebookBidTokenListener, context: Any) {
        completeListener.onComplete(bidToken: "dummy bidder token")
    }
}

public class MolocoBidTokenProviderStandalone: MolocoBidTokenProvider {
    
    public init() {}
    
    public func fetch(completeListener: any MolocoBidTokenListener, context: Any) {
        completeListener.onComplete(molocoBidToken: "dummy bidder token")
    }
}

public class LiftoffBidTokenProviderStandalone: LiftoffBidTokenProvider {
    
    public init() {}
    
    public func fetch(completeListener: any LiftoffBidTokenListener, context: Any) {
        completeListener.onComplete(liftoffBidToken: "dummy bidder token")
    }
}
