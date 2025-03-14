//
//  BidLoaderProvider.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/12/24.
//

import Foundation


public protocol BidLoaderProvider: AnyObject {
    func getBidLoader() -> BidLoader
}
