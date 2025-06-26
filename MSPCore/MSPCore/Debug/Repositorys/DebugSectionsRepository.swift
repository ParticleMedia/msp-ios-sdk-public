import Foundation
import MSPiOSCore

protocol DebugSectionsRepository {
    func fetchDebugSections(placements: [String]) -> [DebugSection]
} 