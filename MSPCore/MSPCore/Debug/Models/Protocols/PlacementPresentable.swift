import Foundation

/// Protocol for types that can be used to generate placement IDs
protocol PlacementPresentable {
    /// The placement ID attachment string that will be used in placement ID generation
    /// Returns nil if no attachment is needed
    var placementIdAttachment: String? { get }
} 