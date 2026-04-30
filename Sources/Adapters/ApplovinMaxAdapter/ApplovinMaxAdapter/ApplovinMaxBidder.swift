//
//  ApplovinMaxBidder.swift
//  ApplovinMaxAdapter
//

import Foundation
import MSPiOSCore

public class ApplovinMaxBidder: MSPiOSCore.Bidder {
    public weak var auctionBidListener: AuctionBidListener?
    public weak var adListener: AdListener?
    public var adRequest: AdRequest?
    public var adNetworkAdapter: AdNetworkAdapter = ApplovinMaxAdapter()

    public override func requestBid(
        adRequest: AdRequest, bidListener: any AuctionBidListener, adListener: any AdListener
    ) {
        self.auctionBidListener = bidListener
        self.adListener = adListener
        self.adRequest = adRequest

        if let auctionBidListener = self.auctionBidListener {
            DispatchQueue.main.async {
                self.adNetworkAdapter.loadAdCreative(
                    bidResponse: self, auctionBidListener: auctionBidListener, adListener: adListener, context: self,
                    adRequest: adRequest, bidderPlacementId: self.bidderPlacementId, bidderFormat: self.bidderFormat,
                    params: self.params)
            }
        }
    }

    public override func setAdMetricReporter(adMetricReporter: AdMetricReporter) {
        self.adNetworkAdapter.setAdMetricReporter(adMetricReporter: adMetricReporter)
    }
}
