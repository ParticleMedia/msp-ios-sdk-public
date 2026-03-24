import Foundation

/// Assembles structured test parameters from flat UI selections.
///
/// Each ad network may require a different wire format for test params
/// (e.g. Nova uses a nested `debug_item` structure). Conforming types
/// encapsulate that knowledge so the ViewModel stays generic.
protocol TestParamAssembler {
    /// Builds the final `testParams` dictionary sent in the ad request.
    /// - Parameters:
    ///   - baseParams: Flat key-value pairs collected from all visible
    ///     `TestParamPresentable` options (e.g. `ad_network`, `creative_type`).
    ///   - toggleValues: Toggle states keyed by toggle ID.
    ///   - chipValues: Selected chip IDs keyed by chip-group ID.
    /// - Returns: A dictionary ready to be passed as `AdRequest.testParams`.
    func assembleTestParams(
        baseParams: [String: Any],
        toggleValues: [String: Bool],
        chipValues: [String: String?]
    ) -> [String: Any]
}
