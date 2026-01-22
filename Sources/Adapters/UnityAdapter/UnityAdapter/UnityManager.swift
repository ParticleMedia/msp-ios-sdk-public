//
//  UnityManager.swift
//  UnityAdapter
//
//  Created by Huanzhi Zhang on 12/23/24.
//

import Foundation
import MSPiOSCore

public class UnityManager: AdNetworkManager {
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        UnityAdapter()
    }

    public override func getAdBidder(bidderPlacementId: String, bidderFormat: AdFormat?) -> Bidder? {
        UnityBidder(name: "unity", bidderPlacementId: bidderPlacementId, bidderFormat: bidderFormat)
    }
}
