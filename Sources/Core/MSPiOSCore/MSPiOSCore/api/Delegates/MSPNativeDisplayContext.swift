//
//  MSPNativeDisplayContext.swift
//  MSPiOSCore
//
//  Created by Pengyu Gou on 2025/10/23.
//

import Foundation

public protocol MSPNativeDisplayContext {}

public struct MSPNativeLabelDisplayContext: MSPNativeDisplayContext {
    public let attributes: [NSAttributedString.Key: Any]

    public init(attributes: [NSAttributedString.Key: Any]) {
        self.attributes = attributes
    }
}
