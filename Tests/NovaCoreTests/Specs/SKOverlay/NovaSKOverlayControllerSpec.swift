import Nimble
import Quick
@testable import NovaCore

final class NovaSKOverlayControllerSpec: QuickSpec {
    override class func spec() {
        describe("NovaSKOverlayController") {
            let testEncryptedToken = "test-encrypted-token"
            let testTrackingURL = URL(string: "https://example.com/click-tracking")!

            var sut: NovaSKOverlayController!

            afterEach {
                sut = nil
            }

            func makeSUT(trackingURL: URL? = testTrackingURL) -> NovaSKOverlayController {
                NovaSKOverlayController(
                    encryptedAdToken: testEncryptedToken,
                    thirdPartyTrackingURL: trackingURL,
                    monitorAppStoreLifecycle: false
                )
            }

            describe("handleOverlayDidFinishPresentation") {
                context("when thirdPartyTrackingURL is provided") {
                    beforeEach {
                        sut = makeSUT()
                    }

                    it("[SKO001] returns skip instead of firing third-party tracking on presentation") {
                        expect(sut.handleOverlayDidFinishPresentation()).to(equal(.skip))
                    }

                    it("[SKO002] records the show timestamp") {
                        expect(sut.skOverlayShowTimestamp).to(beNil())

                        _ = sut.handleOverlayDidFinishPresentation()

                        expect(sut.skOverlayShowTimestamp).notTo(beNil())
                    }

                    it("[SKO002] does not overwrite the existing timestamp on repeated calls") {
                        _ = sut.handleOverlayDidFinishPresentation()
                        let firstTimestamp = sut.skOverlayShowTimestamp

                        _ = sut.handleOverlayDidFinishPresentation()

                        expect(sut.skOverlayShowTimestamp).to(equal(firstTimestamp))
                    }
                }

                context("when thirdPartyTrackingURL is nil") {
                    beforeEach {
                        sut = makeSUT(trackingURL: nil)
                    }

                    it("[SKO003] still returns skip") {
                        expect(sut.handleOverlayDidFinishPresentation()).to(equal(.skip))
                    }
                }
            }
        }
    }
}
