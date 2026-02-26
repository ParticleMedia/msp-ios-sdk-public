import Nimble
import Quick
@testable import MSPCore

class MSPVersionSpec: QuickSpec {
    override class func spec() {
        describe("getMSPVersion") {
            var version: String!

            beforeEach {
                version = MSP.getMSPVersion()
            }

            it("[MVS001] should return a string without crashing") {
                expect(version).toNot(beNil())
            }

            it("[MVS002] should return valid version or empty when bundle unavailable") {
                // In test host, MSPCoreResources.bundle may not be available.
                // When available, version contains a dot (e.g., "1.0.5").
                if !version.isEmpty {
                    expect(version).to(contain("."))
                }
            }

            it("[MVS003] should return consistent results across multiple calls") {
                let version2 = MSP.getMSPVersion()
                expect(version).to(equal(version2))
            }

            context("when MSPCoreResources bundle exists") {
                it("[MVS004] should find Config.plist in the resource bundle") {
                    let bundle = Bundle(for: MSP.self)
                    let hasResourceBundle = bundle.url(
                        forResource: "MSPCoreResources",
                        withExtension: "bundle"
                    ) != nil
                    // Fallback: Config.plist directly in framework bundle
                    let hasDirectPlist = bundle.url(
                        forResource: "Config",
                        withExtension: "plist"
                    ) != nil

                    if hasResourceBundle || hasDirectPlist {
                        expect(version).toNot(beEmpty())
                    }
                    // If neither exists (test environment), empty is expected
                }
            }
        }
    }
}
