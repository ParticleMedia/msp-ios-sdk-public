import Foundation
import MSPiOSCore

class TestLoadAdService: LoadAdRepository {
    private lazy var adLoader = MSPAdLoader()
    private let defaultBannerSize = AdSize(
        width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false)

    func loadAd(
        placementId: String,
        adFormat: AdFormat,
        testParams: [String: Any],
        adListener: AdListener,
        customParams: [String: Any]? = nil
    ) {
        // Start with debug defaults; caller-supplied params take precedence.
        var newCustomParams: [String: Any] = [
            MSPConstants.GOOGLE_AD_MULTI_CONTENT_URLS: [
                "https://www.google.com", "https://newsbreak.com",
            ]
        ]
        if let customParams {
            for (key, value) in customParams {
                newCustomParams[key] = value
            }
        }

        var newTestParams = testParams
        newTestParams["mobilefuse"] = "true"
        let adaptiveBannerSize = adFormat == .rewarded ? nil : defaultBannerSize
        let adSize = adFormat == .rewarded ? nil : defaultBannerSize
        let adRequest = AdRequest(
            customParams: newCustomParams,
            geo: nil,
            context: nil,
            adaptiveBannerSize: adaptiveBannerSize,
            adSize: adSize,
            placementId: placementId,
            adFormat: adFormat,
            testParams: newTestParams
        )
        if adFormat == .rewarded,
            let reward = buildReward(from: testParams)
        {
            adRequest.reward = reward
        }
        adLoader.loadAd(
            placementId: placementId,
            adListener: adListener,
            adRequest: adRequest
        )
    }

    func getAd(placementId: String) -> MSPAd? {
        adLoader.getAd(placementId: placementId)
    }

    private func buildReward(from testParams: [String: Any]) -> Reward? {
        guard let type = testParams["reward_type"] as? String,
            let amountString = testParams["reward_amount"] as? String,
            let amount = Int(amountString)
        else {
            return nil
        }

        return Reward(type: type, amount: amount)
    }
}

class ScopedNetworkLoadAdService: LoadAdRepository {
    private enum Keys {
        static let debugSelectedNetwork = "debug_selected_network"
    }

    private struct ScopedPlacement {
        let placementId: String
        let testAdNetwork: String?
    }

    private lazy var adLoader = MSPAdLoader()
    private let defaultBannerSize = AdSize(
        width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false)

    func loadAd(
        placementId: String,
        adFormat: AdFormat,
        testParams: [String: Any],
        adListener: AdListener,
        customParams: [String: Any]? = nil
    ) {
        guard
            let networkRawValue = customParams?[Keys.debugSelectedNetwork] as? String,
            let network = AdNetwork(rawValue: networkRawValue)
        else {
            adListener.onError(msg: "Scoped Network mode requires a selected network", loadInfo: [:])
            return
        }

        guard let scopedPlacement = scopedPlacement(for: network, adFormat: adFormat) else {
            adListener.onError(
                msg: "Scoped Network mode does not support \(network.displayTitle) \(adFormat)",
                loadInfo: [:]
            )
            return
        }

        var resolvedCustomParams = customParams ?? [:]
        resolvedCustomParams.removeValue(forKey: Keys.debugSelectedNetwork)
        resolvedCustomParams[MSPConstants.GOOGLE_AD_MULTI_CONTENT_URLS] = [
            "https://www.google.com", "https://newsbreak.com",
        ]

        var resolvedTestParams = testParams
        resolvedTestParams["mobilefuse"] = "true"
        if let testAdNetwork = scopedPlacement.testAdNetwork {
            resolvedTestParams["test"] = testPayload(
                overriding: testParams["test"] as? String,
                adNetwork: testAdNetwork
            )
        }
        let adaptiveBannerSize = adFormat == .rewarded ? nil : defaultBannerSize
        let adSize = adFormat == .rewarded ? nil : defaultBannerSize

        let adRequest = AdRequest(
            customParams: resolvedCustomParams,
            geo: nil,
            context: nil,
            adaptiveBannerSize: adaptiveBannerSize,
            adSize: adSize,
            placementId: scopedPlacement.placementId,
            adFormat: adFormat,
            testParams: resolvedTestParams
        )
        if adFormat == .rewarded,
            let reward = buildReward(from: resolvedTestParams["test"] as? String)
        {
            adRequest.reward = reward
        }

        MSPLogger.shared.info(
            message:
                "[ScopedNetworkLoadAdService] resolved placementId=\(scopedPlacement.placementId), network=\(network.displayTitle), adFormat=\(adFormat)"
        )

        adLoader.loadAd(
            placementId: scopedPlacement.placementId,
            adListener: adListener,
            adRequest: adRequest
        )
    }

    func getAd(placementId: String) -> MSPAd? {
        adLoader.getAd(placementId: placementId)
    }

    private func scopedPlacement(for network: AdNetwork, adFormat: AdFormat) -> ScopedPlacement? {
        switch (network, adFormat) {
        case (.google, .banner):
            return ScopedPlacement(
                placementId: "demo-ios-article-top-google-c2s",
                testAdNetwork: "msp_google"
            )
        case (.google, .native):
            return ScopedPlacement(
                placementId: "demo-ios-foryou-large-google-c2s",
                testAdNetwork: "msp_google"
            )
        case (.google, .interstitial):
            return ScopedPlacement(
                placementId: "demo-ios-launch-fullscreen-google-c2s",
                testAdNetwork: "msp_google"
            )
        default:
            return nil
        }
    }

    private func testPayload(overriding payload: String?, adNetwork: String) -> String {
        var json: [String: Any] = [:]
        if let payload,
            let data = payload.data(using: .utf8),
            let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            json = parsed
        }
        json["test_ad"] = true
        json["ad_network"] = adNetwork
        guard
            let data = try? JSONSerialization.data(withJSONObject: json, options: []),
            let jsonString = String(data: data, encoding: .utf8)
        else {
            return "{\"ad_network\":\"\(adNetwork)\",\"test_ad\":true}"
        }
        return jsonString
    }

    private func buildReward(from testParamPayload: String?) -> Reward? {
        guard let testParamPayload,
            let data = testParamPayload.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = json["reward_type"] as? String,
            let amountString = json["reward_amount"] as? String,
            let amount = Int(amountString)
        else {
            return nil
        }

        return Reward(type: type, amount: amount)
    }
}
