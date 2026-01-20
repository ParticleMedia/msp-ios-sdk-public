//
//  FacebookBidTokenListener.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/12/24.
//

import Foundation

public protocol FacebookBidTokenListener: AnyObject {
    func onComplete(bidToken: String)
}
