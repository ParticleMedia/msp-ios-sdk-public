//
//  LoadAdParameters.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 7/9/24.
//

import Foundation

public protocol LoadAdParameters: AdapterParameters {
    func getAdUnitId() -> String
    func getThirdPartyAdPlacementId() -> String
    func getBidPayload() -> String
    func getBidExpirationMillis() -> UInt64
}
