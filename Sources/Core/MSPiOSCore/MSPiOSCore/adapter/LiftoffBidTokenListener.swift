//
//  LiftoffBidTokenListener.swift
//  MSPiOSCore
//
//  Created by Mingming Luo on 2025/12/16.
//

import Foundation

public protocol LiftoffBidTokenListener: AnyObject {
    func onComplete(liftoffBidToken: String)
}
