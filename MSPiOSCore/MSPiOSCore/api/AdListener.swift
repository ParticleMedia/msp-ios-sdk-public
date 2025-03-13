//
//  AdListener.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/11/24.
//

import Foundation
import UIKit


public protocol AdListener: AnyObject {
    
    //Deprecated after SDK Bidding:
    //func onAdLoaded(ad: MSPAd)
    
    func onError(msg: String)
    
    func onAdImpression(ad: MSPAd)
    
    func onAdClick(ad: MSPAd)
    
    func onAdLoaded(placementId: String)
    
    func onAdDismissed(ad: InterstitialAd)
    
    func getRootViewController() -> UIViewController?
    
}
