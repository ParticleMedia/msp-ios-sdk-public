//
//  AdNetworkAdapterProvider.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/12/24.
//

import Foundation

public protocol AdNetworkAdapterProvider: AnyObject {
    func getAdNetworkAdapter(adNetwork: AdNetwork) -> AdNetworkAdapter?

    func getAdNetworkAdaptersCount() -> Int
}
