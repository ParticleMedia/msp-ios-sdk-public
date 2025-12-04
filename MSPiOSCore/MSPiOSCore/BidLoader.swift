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
    
    public init(googleQueryInfoFetcher: GoogleQueryInfoFetcher, facebookBidTokenProvider: FacebookBidTokenProvider, molocoBidTokenProvider: MolocoBidTokenProvider) {
        self.googleQueryInfoFetcher = googleQueryInfoFetcher
        self.facebookBidTokenProvider = facebookBidTokenProvider
        self.molocoBidTokenProvider = molocoBidTokenProvider
    }

    open func loadBid(placementId: String, adParams: [String: Any], bidListener: BidListener, adRequest: AdRequest) {
        
    }
}
