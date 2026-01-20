//
//  AdapterAdLoadError.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 7/9/24.
//

import Foundation

public enum AdapterAdLoadError {
    case NO_FILL

    var message: String {
        switch self {
        case .NO_FILL:
            return "No winning bid received from MSP server"
        }
    }
}
