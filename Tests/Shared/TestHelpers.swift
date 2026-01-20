import Foundation
import Quick
import Nimble
import OHHTTPStubs

/// Global test configuration for MSP SDK tests
/// Provides consistent setup/teardown hooks across all test targets
final class MSPTestConfiguration: QuickConfiguration {
    override class func configure(_ configuration: QCKConfiguration) {
        configuration.beforeEach {
            // Clear any existing network stubs before each test
            HTTPStubs.removeAllStubs()
        }

        configuration.afterEach {
            // Clean up network stubs after each test
            HTTPStubs.removeAllStubs()
        }
    }
}
