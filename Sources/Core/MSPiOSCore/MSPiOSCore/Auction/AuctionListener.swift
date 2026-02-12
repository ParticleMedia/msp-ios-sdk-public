//
//  AuctionListener.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 12/17/24.
//

import Foundation

public protocol AuctionListener: AnyObject {
    func onSuccess(winningBid: AuctionBid, loadInfo: [String: Any])

    func onError(error: String, loadInfo: [String: Any])
}
