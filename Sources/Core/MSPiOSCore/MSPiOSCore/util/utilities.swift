//
//  utilities.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 7/22/24.
//

import Foundation

public func handleAdLoaded(ad: MSPAd, listener: AdListener, adRequest: AdRequest) {
    AdCache.shared.saveAd(placementId: adRequest.placementId, ad: ad)
    listener.onAdLoaded(placementId: adRequest.placementId)
}
