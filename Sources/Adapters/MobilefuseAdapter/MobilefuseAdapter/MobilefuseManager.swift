//
//  MobilefuseManager.swift
//  MobilefuseAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//

import Foundation
import MSPiOSCore

public class MobilefuseManager: AdNetworkManager {
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        return MobilefuseAdapter()
    }

    public override func getAdBidder(bidderPlacementId: String, bidderFormat: AdFormat?) -> Bidder? {
        return MobilefuseBidder(name: "mobilefuse", bidderPlacementId: bidderPlacementId, bidderFormat: bidderFormat)
    }
}
