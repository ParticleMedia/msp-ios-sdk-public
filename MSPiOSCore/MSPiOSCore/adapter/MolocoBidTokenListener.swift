//
//  MolocoBidTokenListener.swift
//  MSPiOSCore
//
//  Created by Mingming Luo on 2025/11/21.
//

import Foundation

public protocol MolocoBidTokenListener: AnyObject {
    func onComplete(molocoBidToken: String)
}
