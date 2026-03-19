import Foundation

/// A synthetic "All Networks" option for the Debug Ad Network section.
/// When selected, no `ad_network` test param is sent, so the server returns all configured bidders.
struct DebugAllNetworksOption: DebugOption, TestParamPresentable {
    var id: String { "all_networks" }
    var displayTitle: String { "All Networks" }
    var isVisible: Bool { true }
    var keyValuePairs: [(String, String)] { [] }
}
