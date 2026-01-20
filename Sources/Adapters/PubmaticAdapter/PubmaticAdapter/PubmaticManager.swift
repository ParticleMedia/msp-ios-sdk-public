//
//  PubmaticManager.swift
//  PubmaticAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//

import Foundation
import MSPiOSCore

public class PubmaticManager: AdNetworkManager {
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        return PubmaticAdapter()
    }

    public override func getAdBidder(bidderPlacementId: String, bidderFormat: AdFormat?) -> Bidder? {
        return PubmaticBidder(name: "pubmatic", bidderPlacementId: bidderPlacementId, bidderFormat: bidderFormat)
    }
}
