//
//  MraidController.swift
//  MSPiOSCore
//
//  Created by Shanyu Li on 2026/2/2.
//

import Foundation

public protocol MraidBehaviorDelegate: AnyObject {
    func mraidOpen(url: URL?)
    func mraidClose()
}

public extension MraidBehaviorDelegate {
    func mraidOpen(url: URL?) {}
    func mraidClose() {}
}
