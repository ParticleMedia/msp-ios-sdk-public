//
//  FacebookBidTokenProvider.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/12/24.
//

import Foundation

public protocol FacebookBidTokenProvider: AnyObject {
    func fetch(completeListener: FacebookBidTokenListener, context: Any)
}
