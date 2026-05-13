import Foundation
import Nimble
import Quick

@testable import NovaCore

final class NovaAdBuilderHighValueSpec: QuickSpec {
    override class func spec() {
        describe("NovaAdBuilder.buildNativeAd highValue propagation") {

            func makeAdItem(highValueJSONLine: String) throws -> AdItem {
                let json = """
                {
                  "creative": {
                    "ctrUrl": "https://example.com/click",
                    "creativeType": "IMAGE",
                    "imageUrl": "https://example.com/image.png"
                  },
                  "encryptedAdToken": "tk",
                  "adId": "ad-1",
                  "adsetId": "set-1",
                  "requestId": "req-1",
                  "price": 0.01\(highValueJSONLine)
                }
                """
                return try JSONDecoder().decode(AdItem.self, from: Data(json.utf8))
            }

            it("propagates highValue=true through builder") {
                let item = try makeAdItem(highValueJSONLine: ", \"highValue\": true")
                let nativeAd = try NovaAdBuilder.buildNativeAd(
                    adItem: item,
                    adUnitId: "unit-1",
                    eCPMInDollar: 0
                )
                expect(nativeAd.highValue) == true
            }

            it("propagates highValue=false through builder") {
                let item = try makeAdItem(highValueJSONLine: ", \"highValue\": false")
                let nativeAd = try NovaAdBuilder.buildNativeAd(
                    adItem: item,
                    adUnitId: "unit-1",
                    eCPMInDollar: 0
                )
                expect(nativeAd.highValue) == false
            }

            it("defaults to false when AdItem.highValue is nil") {
                let item = try makeAdItem(highValueJSONLine: "")
                let nativeAd = try NovaAdBuilder.buildNativeAd(
                    adItem: item,
                    adUnitId: "unit-1",
                    eCPMInDollar: 0
                )
                expect(nativeAd.highValue) == false
            }

            it("defaults to false when server payload is wrong type") {
                let item = try makeAdItem(highValueJSONLine: ", \"highValue\": \"true\"")
                let nativeAd = try NovaAdBuilder.buildNativeAd(
                    adItem: item,
                    adUnitId: "unit-1",
                    eCPMInDollar: 0
                )
                expect(nativeAd.highValue) == false
            }
        }
    }
}
