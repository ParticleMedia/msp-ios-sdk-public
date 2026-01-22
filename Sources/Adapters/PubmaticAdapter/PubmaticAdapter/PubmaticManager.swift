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
        PubmaticAdapter()
    }

    public override func getAdBidder(bidderPlacementId: String, bidderFormat: AdFormat?) -> Bidder? {
        PubmaticBidder(name: "pubmatic", bidderPlacementId: bidderPlacementId, bidderFormat: bidderFormat)
    }
}
