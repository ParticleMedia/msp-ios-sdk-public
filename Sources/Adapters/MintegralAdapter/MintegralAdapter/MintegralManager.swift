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
        MintegralAdapter()
    }

    public override func getAdBidder(bidderPlacementId: String, bidderFormat: AdFormat?) -> Bidder? {
        MintegralBidder(name: "mintegral", bidderPlacementId: bidderPlacementId, bidderFormat: bidderFormat)
    }
}
