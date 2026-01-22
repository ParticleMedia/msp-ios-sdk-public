//
//  AuctionListener.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 12/17/24.
//

import Foundation

public protocol AuctionListener: AnyObject {
    func onSuccess(winningBid: AuctionBid)

    func onError(error: String)
}
