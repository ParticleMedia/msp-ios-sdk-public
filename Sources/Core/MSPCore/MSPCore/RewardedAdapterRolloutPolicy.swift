//
//  RewardedAdapterRolloutPolicy.swift
//  MSPCore
//

import Foundation
import MSPiOSCore

internal protocol RewardedAdapterRolloutPolicy {
    func isEnabled(networkName: String, placementId: String) -> Bool
}

internal struct ClientRewardedAdapterRolloutPolicy: RewardedAdapterRolloutPolicy {
    private let enabledNetworks: Set<AdNetwork>

    init(enabledNetworks: Set<AdNetwork> = [.google, .facebook]) {
        self.enabledNetworks = enabledNetworks
    }

    func isEnabled(networkName: String, placementId: String) -> Bool {
        guard let network = AdNetwork(rawValue: networkName) else {
            return false
        }
        return enabledNetworks.contains(network)
    }
}
