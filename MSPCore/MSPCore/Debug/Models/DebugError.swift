import Foundation

/// Error types that can occur during debug operations
enum DebugError: Error, LocalizedError {
    case failedToGeneratePlacementId
    case invalidSelection
    case missingRequiredOptions
    case sdkError(String)
    
    var errorDescription: String? {
        switch self {
        case .failedToGeneratePlacementId:
            return "Failed to generate placement ID"
        case .invalidSelection:
            return "Invalid selection"
        case .missingRequiredOptions:
            return "Missing required options"
        case .sdkError(let message):
            return "SDK Error: \(message)"
        }
    }
} 