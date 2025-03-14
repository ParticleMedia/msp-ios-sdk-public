//
//  AdNetworkAdapter.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/11/24.
//
import Foundation

public protocol AdNetworkAdapter: AnyObject {
    //Deprecated after SDK Bidding:
    //func loadAdCreative(bidResponse: Any, adListener: AdListener, context: Any, adRequest: AdRequest)
    
    func loadAdCreative(bidResponse: Any, auctionBidListener: AuctionBidListener, adListener: AdListener, context: Any, adRequest: AdRequest, bidderPlacementId: String, bidderFormat: AdFormat?, params: [String: String]?)
    
    func initialize(initParams: InitializationParameters,
                    adapterInitListener: AdapterInitListener,
                    context: Any?)
    
    func destroyAd()
    
    func prepareViewForInteraction(nativeAd: NativeAd, nativeAdView: Any)
    
    func setAdMetricReporter(adMetricReporter: AdMetricReporter)
    
    func getAdNetwork() -> AdNetwork
}
