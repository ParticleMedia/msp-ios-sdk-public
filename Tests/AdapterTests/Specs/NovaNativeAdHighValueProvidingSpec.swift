import Foundation
import Nimble
import Quick

@testable import MSPiOSCore
@testable import MSPNovaAdapter
@testable import NovaCore

final class NovaNativeAdHighValueProvidingSpec: QuickSpec {
    override class func spec() {
        describe("NovaNativeAdHighValueProviding extension") {

            // Build a NovaCore.NovaNativeAdItem with a chosen highValue value via
            // the public NovaAdBuilder API (only path; the throwing init is internal).
            func makeNovaNativeAdItem(highValueJSONLine: String) throws -> NovaNativeAdItem {
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
                let adItem = try JSONDecoder().decode(AdItem.self, from: Data(json.utf8))
                return try NovaAdBuilder.buildNativeAd(
                    adItem: adItem,
                    adUnitId: "unit-1",
                    eCPMInDollar: 0
                )
            }

            describe("Nova native ad with highValue=true") {
                it("exposes highValue=true via MSPiOSCore.NativeAd surface") {
                    let novaAd = NovaNativeAd(
                        adNetworkAdapter: RewardedAdNetworkAdapterStub(),
                        title: "", body: "", advertiser: "", callToAction: ""
                    )
                    novaAd.nativeAdItem = try makeNovaNativeAdItem(highValueJSONLine: ", \"highValue\": true")

                    let asNativeAd: MSPiOSCore.NativeAd = novaAd
                    expect(asNativeAd.highValue) == true
                }

                it("writes highValue into adInfo for downstream observability") {
                    let novaAd = NovaNativeAd(
                        adNetworkAdapter: RewardedAdNetworkAdapterStub(),
                        title: "", body: "", advertiser: "", callToAction: ""
                    )
                    novaAd.nativeAdItem = try makeNovaNativeAdItem(highValueJSONLine: ", \"highValue\": true")

                    expect(novaAd.adInfo[MSPConstants.AD_INFO_NOVA_HIGH_VALUE] as? Bool) == true
                }
            }

            describe("Nova native ad with highValue=false") {
                it("exposes highValue=false via MSPiOSCore.NativeAd surface") {
                    let novaAd = NovaNativeAd(
                        adNetworkAdapter: RewardedAdNetworkAdapterStub(),
                        title: "", body: "", advertiser: "", callToAction: ""
                    )
                    novaAd.nativeAdItem = try makeNovaNativeAdItem(highValueJSONLine: ", \"highValue\": false")

                    let asNativeAd: MSPiOSCore.NativeAd = novaAd
                    expect(asNativeAd.highValue) == false
                }

                it("writes highValue=false into adInfo for downstream observability") {
                    let novaAd = NovaNativeAd(
                        adNetworkAdapter: RewardedAdNetworkAdapterStub(),
                        title: "", body: "", advertiser: "", callToAction: ""
                    )
                    novaAd.nativeAdItem = try makeNovaNativeAdItem(highValueJSONLine: ", \"highValue\": false")

                    expect(novaAd.adInfo[MSPConstants.AD_INFO_NOVA_HIGH_VALUE] as? Bool) == false
                }
            }

            describe("Nova native ad without highValue field") {
                it("defaults to false (builder ?? fallback)") {
                    let novaAd = NovaNativeAd(
                        adNetworkAdapter: RewardedAdNetworkAdapterStub(),
                        title: "", body: "", advertiser: "", callToAction: ""
                    )
                    novaAd.nativeAdItem = try makeNovaNativeAdItem(highValueJSONLine: "")

                    let asNativeAd: MSPiOSCore.NativeAd = novaAd
                    expect(asNativeAd.highValue) == false
                }
            }

            describe("Nova native ad without nativeAdItem injected") {
                it("returns false (nil-coalesce on nativeAdItem)") {
                    let novaAd = NovaNativeAd(
                        adNetworkAdapter: RewardedAdNetworkAdapterStub(),
                        title: "", body: "", advertiser: "", callToAction: ""
                    )

                    let asNativeAd: MSPiOSCore.NativeAd = novaAd
                    expect(asNativeAd.highValue) == false
                }
            }

            describe("Non-Nova MSPiOSCore.NativeAd") {
                it("returns false (as? NovaNativeAd cast fails)") {
                    let plainAd = MSPiOSCore.NativeAd(
                        adNetworkAdapter: RewardedAdNetworkAdapterStub(),
                        title: "", body: "", advertiser: "", callToAction: ""
                    )

                    expect(plainAd.highValue) == false
                }
            }
        }
    }
}
