//
//  AmazonManager.swift
//  AmazonAdapter
//
//  Created by Huanzhi Zhang on 8/8/25.
//

import Foundation
import MSPiOSCore

public class AmazonManager: AdNetworkManager {
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        return AmazonAdapter()
    }

    public override func getAdBidder(bidderPlacementId: String, bidderFormat: AdFormat?) -> Bidder? {
        return AmazonBidder(name: "amazon", bidderPlacementId: bidderPlacementId, bidderFormat: bidderFormat)
    }
}
