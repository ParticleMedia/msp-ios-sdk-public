import Nimble
import Quick
@testable import NovaCore

final class NovaAdClickPayloadSpec: QuickSpec {
    override class func spec() {
        describe("NovaAdClickPayload") {
            context("when open payload is a dictionary") {
                it("[ACP001] extracts url, click area, and reporting extras") {
                    let payload = NovaAdClickPayload.openPayload(
                        from: [
                            "url": "https://example.com/landing",
                            "click_area_name": "html",
                            "product_id": "product-123",
                            "grid_idx": 7,
                            "ignored": "value",
                        ]
                    )

                    expect(payload.url?.absoluteString).to(equal("https://example.com/landing"))
                    expect(payload.area).to(equal(.html))
                    expect(payload.extras).to(equal([
                        "product_id": "product-123",
                        "grid_idx": "7",
                    ]))
                }
            }

            context("when open payload is a JSON string") {
                it("[ACP002] preserves legacy string payload parsing") {
                    let jsonString = """
                    {
                        "url": "https://example.com/legacy",
                        "click_area_name": "cta",
                        "product_id": 12345,
                        "grid_idx": "2"
                    }
                    """

                    let payload = NovaAdClickPayload.openPayload(from: jsonString)

                    expect(payload.url?.absoluteString).to(equal("https://example.com/legacy"))
                    expect(payload.area).to(equal(.cta))
                    expect(payload.extras).to(equal([
                        "product_id": "12345",
                        "grid_idx": "2",
                    ]))
                }
            }

            context("when open payload has empty or non-whitelisted extras") {
                it("[ACP003] drops values that should not enter DSP reporting") {
                    let payload = NovaAdClickPayload.openPayload(
                        from: [
                            "product_id": "",
                            "grid_idx": ["invalid"],
                            "click_seq": "999",
                        ]
                    )

                    expect(payload.extras).to(beEmpty())
                    // Missing url/click_area_name fall back to safe defaults rather than crash
                    expect(payload.url).to(beNil())
                    expect(payload.area).to(equal(.custom("")))
                }
            }

            context("when open payload is missing or of an unsupported type") {
                it("[ACP004] returns an empty payload without crashing") {
                    let nilPayload = NovaAdClickPayload.openPayload(from: nil)
                    expect(nilPayload.url).to(beNil())
                    expect(nilPayload.area).to(equal(.custom("")))
                    expect(nilPayload.extras).to(beEmpty())

                    let arrayPayload = NovaAdClickPayload.openPayload(from: ["unexpected"])
                    expect(arrayPayload.url).to(beNil())
                    expect(arrayPayload.area).to(equal(.custom("")))
                    expect(arrayPayload.extras).to(beEmpty())

                    let malformedJSONPayload = NovaAdClickPayload.openPayload(from: "{not json")
                    expect(malformedJSONPayload.url).to(beNil())
                    expect(malformedJSONPayload.area).to(equal(.custom("")))
                    expect(malformedJSONPayload.extras).to(beEmpty())
                }
            }
        }
    }
}
