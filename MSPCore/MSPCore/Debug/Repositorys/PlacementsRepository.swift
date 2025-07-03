import Foundation

protocol PlacementsRepository {
    func fetchPlacements() -> [String]
    
    /// Fetches a placement ID based on the provided debug options
    /// - Parameter options: Array of debug options to generate placement ID for
    /// - Returns: Optional placement ID string (nil if placement cannot be generated)
    func fetchPlacements(from options: [DebugOption]) -> String?
} 
