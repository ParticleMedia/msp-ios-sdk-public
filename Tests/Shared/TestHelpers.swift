/// Global test configuration for MSP SDK tests
/// Provides consistent setup/teardown hooks across all test targets
import Foundation
import Nimble
import OHHTTPStubs
import Quick

final class MSPTestConfiguration: QuickConfiguration {
    override class func configure(_ configuration: QCKConfiguration) {
        configuration.beforeEach {
            HTTPStubs.removeAllStubs()
        }

        configuration.afterEach {
            HTTPStubs.removeAllStubs()
        }
    }
}
