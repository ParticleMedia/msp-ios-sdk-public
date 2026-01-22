//
//  MolocoManager.swift
//  MolocoAdapter
//
//  Created by Mingming Luo on 2025/11/19.
//

import Foundation
import MSPiOSCore

public class MolocoManager: AdNetworkManager {
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        MolocoAdapter()
    }

    public override func getAdBidder(bidderPlacementId: String, bidderFormat: AdFormat?) -> Bidder? {
        MolocoBidder(name: "moloco", bidderPlacementId: bidderPlacementId, bidderFormat: bidderFormat)
    }
}
