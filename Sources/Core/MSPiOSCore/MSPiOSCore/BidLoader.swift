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
    
    public init(googleQueryInfoFetcher: GoogleQueryInfoFetcher, facebookBidTokenProvider: FacebookBidTokenProvider) {
        self.googleQueryInfoFetcher = googleQueryInfoFetcher
        self.facebookBidTokenProvider = facebookBidTokenProvider
    }

    open func loadBid(placementId: String, adParams: [String: Any], bidListener: BidListener, adRequest: AdRequest) {
        
    }
}
