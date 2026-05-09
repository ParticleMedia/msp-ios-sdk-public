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
    private let enabledNetworkNames: Set<String>

    init(enabledNetworks: Set<AdNetwork> = [.google, .facebook, .applovin], enabledNetworkNames: Set<String> = ["msp"]) {
        self.enabledNetworks = enabledNetworks
        self.enabledNetworkNames = enabledNetworkNames
    }

    func isEnabled(networkName: String, placementId: String) -> Bool {
        if enabledNetworkNames.contains(networkName) {
            return true
        }
        guard let network = AdNetwork(rawValue: networkName) else {
            return false
        }
        return enabledNetworks.contains(network)
    }
}
