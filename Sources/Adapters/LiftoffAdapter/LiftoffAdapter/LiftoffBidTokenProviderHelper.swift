//
//  LiftoffBidTokenProviderHelper.swift
//  LiftoffAdapter
//
//  Created by Mingming Luo on 2025/12/16.
//

import Foundation
import MSPiOSCore
import VungleAdsSDK

public class LiftoffBidTokenProviderHelper: LiftoffBidTokenProvider {
    public init() {
    }

    public func fetch(completeListener: any LiftoffBidTokenListener, context: Any) {
        let biddingToken = VungleAds.getBiddingToken()
        completeListener.onComplete(liftoffBidToken: biddingToken)
    }
}
