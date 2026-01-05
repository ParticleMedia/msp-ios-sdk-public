//
//  MolocoBidTokenProvider.swift
//  MSPiOSCore
//
//  Created by Mingming Luo on 2025/11/21.
//

import Foundation

public protocol MolocoBidTokenProvider: AnyObject {
    func fetch(completeListener: MolocoBidTokenListener, context: Any)
}
