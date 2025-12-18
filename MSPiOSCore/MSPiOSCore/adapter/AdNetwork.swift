//
//  AdNetwork.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/12/24.
//

import Foundation

public enum AdNetwork: String, CaseIterable {
    case unknown = "Unknown"
    
    case google = "google"
    case facebook = "facebook"
    case prebid = "prebid"
    case nova = "nova"
    case unity = "unity"
    case pubmatic = "pubmatic"
    case mintegral = "mintegral"
    case mobilefuse = "mobilefuse"
    case inmobi = "inmobi"
    case amazon = "amazon"
    case moloco = "moloco"
    case liftoff = "liftoff"
}
