/// Utility for loading test fixture files
import Foundation

enum FixtureLoader {
    /// Returns the path to a fixture file
    /// - Parameter filename: Name of the fixture file (e.g., "bid_response_success.json")
    /// - Returns: Full path to the fixture file, or nil if not found
    static func path(for filename: String) -> String? {
        for bundle in Bundle.allBundles {
            if let path = bundle.path(
                forResource: filename.replacingOccurrences(of: ".json", with: ""),
                ofType: "json")
            {
                return path
            }
        }

        // Fallback: Check packages/mock-data/ relative to the project root
        let fixturesPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("packages")
            .appendingPathComponent("mock-data")
            .appendingPathComponent("debug")
            .appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: fixturesPath.path) {
            return fixturesPath.path
        }

        return nil
    }

    /// Load and decode a JSON fixture file
    /// - Parameter filename: Name of the fixture file
    /// - Returns: Decoded object of type T
    static func load<T: Decodable>(_ filename: String) throws -> T {
        guard let path = path(for: filename) else {
            throw FixtureError.fileNotFound(filename)
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Load raw data from a fixture file
    /// - Parameter filename: Name of the fixture file
    /// - Returns: Raw data contents
    static func loadData(_ filename: String) throws -> Data {
        guard let path = path(for: filename) else {
            throw FixtureError.fileNotFound(filename)
        }
        return try Data(contentsOf: URL(fileURLWithPath: path))
    }
}

enum FixtureError: Error {
    case fileNotFound(String)
}
