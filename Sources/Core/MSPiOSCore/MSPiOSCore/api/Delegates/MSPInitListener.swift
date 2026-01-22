//
//  MSPInitListener.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/12/24.
//

import Foundation

public protocol MSPInitListener: AnyObject {
    func onComplete(status: MSPInitStatus, message: String)
}
