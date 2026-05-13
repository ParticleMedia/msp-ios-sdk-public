import Foundation
import Nimble
import Quick

@testable import NovaCore

final class AdItemHighValueDecodingSpec: QuickSpec {
    override class func spec() {
        describe("AdItem highValue decoding") {

            func decode(_ snippet: String) throws -> AdItem {
                let json = """
                {
                  "creative": {
                    "ctrUrl": "https://example.com/click",
                    "creativeType": "IMAGE"
                  },
                  "encryptedAdToken": "tk",
                  "adId": "ad-1",
                  "adsetId": "set-1",
                  "requestId": "req-1",
                  "price": 0.01\(snippet)
                }
                """
                return try JSONDecoder().decode(AdItem.self, from: Data(json.utf8))
            }

            it("decodes highValue=true from camelCase key") {
                let item = try decode(", \"highValue\": true")
                expect(item.highValue) == true
            }

            it("decodes highValue=false from camelCase key") {
                let item = try decode(", \"highValue\": false")
                expect(item.highValue) == false
            }

            it("collapses missing highValue field to nil") {
                let item = try decode("")
                expect(item.highValue).to(beNil())
            }

            it("collapses explicit null highValue to nil") {
                let item = try decode(", \"highValue\": null")
                expect(item.highValue).to(beNil())
            }

            it("collapses non-Bool highValue payload to nil (string)") {
                let item = try decode(", \"highValue\": \"true\"")
                expect(item.highValue).to(beNil())
            }

            it("collapses non-Bool highValue payload to nil (number)") {
                let item = try decode(", \"highValue\": 1")
                expect(item.highValue).to(beNil())
            }

            it("ignores high_value snake_case key (client contract is camelCase)") {
                let item = try decode(", \"high_value\": true")
                expect(item.highValue).to(beNil())
            }

            it("ignores highValue placed inside creative (wrong nesting level)") {
                let json = """
                {
                  "creative": {
                    "ctrUrl": "https://example.com/click",
                    "creativeType": "IMAGE",
                    "highValue": true
                  },
                  "encryptedAdToken": "tk",
                  "adId": "ad-1",
                  "adsetId": "set-1",
                  "requestId": "req-1",
                  "price": 0.01
                }
                """
                let item = try JSONDecoder().decode(AdItem.self, from: Data(json.utf8))
                expect(item.highValue).to(beNil())
            }
        }
    }
}
