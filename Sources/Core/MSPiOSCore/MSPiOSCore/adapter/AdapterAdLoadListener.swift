//
//  AdapterAdLoadListener.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/12/24.
//

import Foundation

public protocol AdapterAdLoadListener: AnyObject {
    func onAdLoadedFailed(error: AdapterAdLoadError)
}
