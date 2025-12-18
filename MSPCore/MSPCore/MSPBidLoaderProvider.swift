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
    public var molocoBidTokenProvider: MolocoBidTokenProvider?
    public var liftoffBidTokenProvider: LiftoffBidTokenProvider?
    public weak var bidLoader: BidLoader?
    
    public init() {
        
    }
    
    public func getBidLoader() -> BidLoader {
        let tokenProviders = BidTokenProviders()
            .with(googleQueryInfoFetcher: googleQueryInfoFetcher ?? GoogleQueryInfoFetcherStandalone())
            .with(facebookBidTokenProvider: facebookBidTokenProvider ?? FacebookBidTokenProviderStandalone())
            .with(molocoBidTokenProvider: molocoBidTokenProvider ?? MolocoBidTokenProviderStandalone())
            .with(liftoffBidTokenProvider: liftoffBidTokenProvider ?? LiftoffBidTokenProviderStandalone())

        let bidLoader = PrebidBidLoader(tokenProviders: tokenProviders)
        bidLoader.adMetricReporter = AdMetricReporterImp()
        self.bidLoader = bidLoader
        return bidLoader
    }
}
