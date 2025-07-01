import Foundation
import MSPiOSCore

class TestPlacementsService: PlacementsRepository {
    /// Returns a predefined list of hardcoded placement IDs for testing
    /// - Returns: Array of placement ID strings
    func fetchPlacements() -> [String] {
        return []
    }
    
    /// Generates a dynamic placement ID based on the provided debug options
    /// Combines placement ID attachments from each option and prefixes with "demo-ios-"
    /// Ensures AdFormat comes first, then AdNetwork in the placement ID
    /// - Parameter options: Array of debug options (e.g., AdNetwork, AdFormat) that conform to DebugOption
    /// - Returns: Optional placement ID string, nil if no valid placement attachments are found
    func fetchPlacements(from options: [DebugOption]) -> String? {
        // Sort options to ensure AdFormat comes first, then AdNetwork
        let sortedOptions = options.sorted { option1, option2 in
            let isOption1AdFormat = option1 is AdFormat
            let isOption2AdFormat = option2 is AdFormat
            let isOption1AdNetwork = option1 is AdNetwork
            let isOption2AdNetwork = option2 is AdNetwork
            
            // AdFormat should come first
            if isOption1AdFormat && !isOption2AdFormat { return true }
            if !isOption1AdFormat && isOption2AdFormat { return false }
            
            // AdNetwork should come second
            if isOption1AdNetwork && !isOption2AdNetwork { return true }
            if !isOption1AdNetwork && isOption2AdNetwork { return false }
            
            // For other types, maintain original order
            return false
        }
        
        let placementIds = sortedOptions.compactMap { $0.placementIdAttachment }
        guard !placementIds.isEmpty else { return nil }
        return "demo-ios-" + placementIds.joined()
    }
} 
