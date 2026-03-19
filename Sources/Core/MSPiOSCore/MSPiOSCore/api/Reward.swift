//
//  Reward.swift
//  MSPiOSCore
//

import Foundation

/// Describes the reward associated with a server-side rewarded ad request or loaded ad.
public struct Reward: Equatable, Codable, Sendable {
    /// The reward category label, such as `coins` or `lives`.
    public let type: String

    /// The quantity of rewarded units.
    public let amount: Int

    /// Creates reward metadata for a server-side rewarded ad request or loaded ad.
    /// - Parameters:
    ///   - type: The reward category label.
    ///   - amount: The quantity of rewarded units.
    public init(type: String, amount: Int) {
        self.type = type
        self.amount = amount
    }
}
