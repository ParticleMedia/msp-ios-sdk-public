//
//  MintegralManager.swift
//  MintegralAdapter
//
//  Created by Huanzhi Zhang on 2/5/25.
//


import Foundation
import MSPiOSCore

public class MintegralManager: AdNetworkManager {
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        return MintegralAdapter()
    }

    public override func getAdBidder(bidderPlacementId: String, bidderFormat: AdFormat?) -> Bidder? {
        return MintegralBidder(name: "mintegral", bidderPlacementId: bidderPlacementId, bidderFormat: bidderFormat)
    }
}
