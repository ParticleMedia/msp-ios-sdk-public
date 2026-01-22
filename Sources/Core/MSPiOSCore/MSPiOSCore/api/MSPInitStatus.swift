//
//  MSPInitStatus.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/12/24.
//

import Foundation

public enum MSPInitStatus {
    case SUCCESS

    var message: String {
        switch self {
        case .SUCCESS:
            return "MSP SDK is successfully initialized"
        }
    }
}
