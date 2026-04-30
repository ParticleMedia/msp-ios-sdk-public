//
//  ApplovinMaxNativeDelegateHandler.swift
//  ApplovinMaxAdapter
//

import AppLovinSDK
import Foundation
import MSPiOSCore

class ApplovinMaxNativeDelegateHandler: NSObject, MANativeAdDelegate, MAAdRevenueDelegate {
    weak var adapter: ApplovinMaxAdapter?

    init(adapter: ApplovinMaxAdapter) {
        self.adapter = adapter
    }

    // MARK: - MANativeAdDelegate

    func didLoadNativeAd(_ nativeAdView: MANativeAdView?, for ad: MAAd) {
        MSPLogger.shared.info(message: "[Adapter: ApplovinMax] Native ad loaded, adUnitId = \(ad.adUnitIdentifier)")
        DispatchQueue.main.async { [weak self] in
            guard let self, let adapter = self.adapter else { return }
            adapter.loadedNativeAd = ad

            let nativeAd = ApplovinMaxNativeAd(
                adNetworkAdapter: adapter,
                title: ad.nativeAd?.title ?? "",
                body: ad.nativeAd?.body ?? "",
                advertiser: ad.nativeAd?.advertiser ?? "",
                callToAction: ad.nativeAd?.callToAction ?? "")
            nativeAd.loadedAd = ad
            nativeAd.nativeAdLoader = adapter.nativeAdLoader

            if let mediaView = ad.nativeAd?.mediaView {
                nativeAd.mediaView = mediaView
            }

            adapter.crid = ad.creativeIdentifier
            adapter.priceInDollar = ad.revenue
            adapter.mspNativeAd = nativeAd

            adapter.handleAdLoaded(mspAd: nativeAd)
        }
    }

    func didFailToLoadNativeAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        MSPLogger.shared.info(
            message:
                "[Adapter: ApplovinMax] Native ad failed to load, adUnitId = \(adUnitIdentifier), error = \(error.message)"
        )
        adapter?.handleAdLoadFailed(error: error.message)
    }

    func didClickNativeAd(_ ad: MAAd) {
        MSPLogger.shared.info(message: "[Adapter: ApplovinMax] Native ad clicked, adUnitId = \(ad.adUnitIdentifier)")
        if let mspNativeAd = adapter?.mspNativeAd {
            adapter?.handleAdClicked(mspAd: mspNativeAd)
        }
    }

    func didExpireNativeAd(_ ad: MAAd) {
        MSPLogger.shared.info(message: "[Adapter: ApplovinMax] Native ad expired, adUnitId = \(ad.adUnitIdentifier)")
    }

    // MARK: - MAAdRevenueDelegate

    func didPayRevenue(for ad: MAAd) {
        if let mspNativeAd = adapter?.mspNativeAd {
            adapter?.handleAdImpression(mspAd: mspNativeAd)
        }
    }
}
