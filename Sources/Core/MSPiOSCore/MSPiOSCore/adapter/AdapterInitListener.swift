//
//  AdapterInitListener.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/12/24.
//

import Foundation

public protocol AdapterInitListener: AnyObject {
    func onComplete(adNetwork: AdNetwork, adapterInitStatus: AdapterInitStatus, message: String)
}
