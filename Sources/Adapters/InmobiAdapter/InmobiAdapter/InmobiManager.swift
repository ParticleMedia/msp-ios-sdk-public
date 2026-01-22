//
//  InmobiManager.swift
//  InmobiAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//

import Foundation
import MSPiOSCore

public class InmobiManager: AdNetworkManager {
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        InmobiAdapter()
    }

    public override func getAdBidder(bidderPlacementId: String, bidderFormat: AdFormat?) -> Bidder? {
        InmobiBidder(name: "inmobi", bidderPlacementId: bidderPlacementId, bidderFormat: bidderFormat)
    }
}
