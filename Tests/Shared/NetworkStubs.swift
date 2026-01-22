/// Network stubbing utilities for deterministic test results
import Foundation
import OHHTTPStubs

enum NetworkStub {
    /// Stub a successful response with JSON data
    /// - Parameters:
    ///   - path: URL path to match (e.g., "/v1/bid")
    ///   - jsonFile: Name of JSON fixture file (without .json extension)
    ///   - statusCode: HTTP status code (default: 200)
    ///   - delay: Response delay in seconds (default: 0)
    @discardableResult
    static func stubSuccess(
        path: String,
        jsonFile: String,
        statusCode: Int32 = 200,
        delay: TimeInterval = 0
    ) -> HTTPStubsDescriptor {
        HTTPStubs.stubRequests(
            passingTest: { request in
                request.url?.path.hasSuffix(path) ?? false
            },
            withStubResponse: { _ in
                let stubPath = FixtureLoader.path(for: "\(jsonFile).json")
                return HTTPStubsResponse(
                    fileAtPath: stubPath ?? "",
                    statusCode: statusCode,
                    headers: ["Content-Type": "application/json"]
                ).requestTime(delay, responseTime: 0)
            })
    }

    /// Stub an error response
    /// - Parameters:
    ///   - path: URL path to match
    ///   - statusCode: HTTP status code (default: 500)
    ///   - jsonFile: Optional error JSON fixture file
    @discardableResult
    static func stubError(
        path: String,
        statusCode: Int32 = 500,
        jsonFile: String? = nil
    ) -> HTTPStubsDescriptor {
        HTTPStubs.stubRequests(
            passingTest: { request in
                request.url?.path.hasSuffix(path) ?? false
            },
            withStubResponse: { _ in
                if let jsonFile = jsonFile,
                    let stubPath = FixtureLoader.path(for: "\(jsonFile).json")
                {
                    return HTTPStubsResponse(
                        fileAtPath: stubPath,
                        statusCode: statusCode,
                        headers: ["Content-Type": "application/json"]
                    )
                }
                return HTTPStubsResponse(
                    jsonObject: ["error": "Internal Server Error"],
                    statusCode: statusCode,
                    headers: ["Content-Type": "application/json"]
                )
            })
    }

    /// Stub a timeout response
    /// - Parameters:
    ///   - path: URL path to match
    ///   - timeout: Timeout duration in seconds (default: 30)
    @discardableResult
    static func stubTimeout(path: String, timeout: TimeInterval = 30) -> HTTPStubsDescriptor {
        HTTPStubs.stubRequests(
            passingTest: { request in
                request.url?.path.hasSuffix(path) ?? false
            },
            withStubResponse: { _ in
                HTTPStubsResponse(
                    error: NSError(
                        domain: NSURLErrorDomain,
                        code: NSURLErrorTimedOut,
                        userInfo: nil
                    )
                ).requestTime(timeout, responseTime: 0)
            })
    }
}
