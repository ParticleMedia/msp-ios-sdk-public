/// Async test helpers extending Nimble's waitUntil
import Foundation
import Nimble

extension AsyncDefaults {
    /// Default timeout for async tests (5 seconds)
    public static var timeout: NimbleTimeInterval = .seconds(5)
}

/// Convenience wrapper for async/await testing
func waitForAsync<T>(
    timeout: NimbleTimeInterval = .seconds(5),
    action: @escaping () async throws -> T
) throws -> T {
    var result: Result<T, Error>?

    waitUntil(timeout: timeout) { done in
        Task {
            do {
                let value = try await action()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
            done()
        }
    }

    switch result {
    case .success(let value):
        return value
    case .failure(let error):
        throw error
    case .none:
        throw AsyncTestError.timeout
    }
}

enum AsyncTestError: Error {
    case timeout
}
