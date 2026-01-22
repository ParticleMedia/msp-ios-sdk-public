//
//  LiftoffManager.swift
//  LiftoffAdapter
//
//  Created by Mingming Luo on 2025/12/9.
//

import Foundation
import MSPiOSCore

public class LiftoffManager: AdNetworkManager {
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        LiftoffAdapter()
    }

    public override func getAdBidder(bidderPlacementId: String, bidderFormat: AdFormat?) -> Bidder? {
        LiftoffBidder(name: "liftoff", bidderPlacementId: bidderPlacementId, bidderFormat: bidderFormat)
    }
}
