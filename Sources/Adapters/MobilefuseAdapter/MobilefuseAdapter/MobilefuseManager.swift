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
        MobilefuseAdapter()
    }

    public override func getAdBidder(bidderPlacementId: String, bidderFormat: AdFormat?) -> Bidder? {
        MobilefuseBidder(name: "mobilefuse", bidderPlacementId: bidderPlacementId, bidderFormat: bidderFormat)
    }
}
