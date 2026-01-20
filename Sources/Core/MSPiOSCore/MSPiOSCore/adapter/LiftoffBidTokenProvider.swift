//
//  LiftoffBidTokenProvider.swift
//  MSPiOSCore
//
//  Created by Mingming Luo on 2025/12/16.
//

import Foundation

public protocol LiftoffBidTokenProvider: AnyObject {
    func fetch(completeListener: LiftoffBidTokenListener, context: Any)
}
