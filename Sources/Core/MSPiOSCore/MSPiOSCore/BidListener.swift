//
//  BidListener.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/12/24.
//

import Foundation


public protocol BidListener: AnyObject {
    
    func onBidResponse(bidResponse: Any, adNetwork: AdNetwork)
    
    func onError(msg: String)
    
}
