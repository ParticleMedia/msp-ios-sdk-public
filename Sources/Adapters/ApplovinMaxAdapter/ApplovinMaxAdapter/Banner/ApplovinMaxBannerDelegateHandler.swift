//
//  ApplovinMaxBannerDelegateHandler.swift
//  ApplovinMaxAdapter
//

import AppLovinSDK
import Foundation
import MSPiOSCore

class ApplovinMaxBannerDelegateHandler: NSObject, MAAdViewAdDelegate {
    weak var adapter: ApplovinMaxAdapter?

    init(adapter: ApplovinMaxAdapter) {
        self.adapter = adapter
    }

    func didLoad(_ ad: MAAd) {
        MSPLogger.shared.info(message: "[Adapter: ApplovinMax] Banner ad loaded, adUnitId = \(ad.adUnitIdentifier)")
        guard let adapter = self.adapter, let bannerAdView = adapter.bannerAdView else { return }
        adapter.crid = ad.creativeIdentifier
        adapter.priceInDollar = ad.revenue
        let bannerAd = BannerAd(adView: bannerAdView, adNetworkAdapter: adapter)
        adapter.mspBannerAd = bannerAd
        adapter.handleAdLoaded(mspAd: bannerAd)
        adapter.handleAdImpression(mspAd: bannerAd)
    }

    func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        MSPLogger.shared.info(
            message:
                "[Adapter: ApplovinMax] Banner ad failed to load, adUnitId = \(adUnitIdentifier), error = \(error.message)"
        )
        adapter?.handleAdLoadFailed(error: error.message)
    }

    func didClick(_ ad: MAAd) {
        MSPLogger.shared.info(message: "[Adapter: ApplovinMax] Banner ad clicked, adUnitId = \(ad.adUnitIdentifier)")
        if let mspBannerAd = adapter?.mspBannerAd {
            adapter?.handleAdClicked(mspAd: mspBannerAd)
        }
    }

    func didFail(toDisplay ad: MAAd, withError error: MAError) {
        MSPLogger.shared.error(
            tag: "Banner",
            message:
                "[Adapter: ApplovinMax] Banner failed to display, adUnitId = \(ad.adUnitIdentifier), error = \(error.message)"
        )
    }

    func didExpand(_ ad: MAAd) {
        MSPLogger.shared.info(message: "[Adapter: ApplovinMax] Banner ad expanded, adUnitId = \(ad.adUnitIdentifier)")
    }

    func didCollapse(_ ad: MAAd) {
        MSPLogger.shared.info(message: "[Adapter: ApplovinMax] Banner ad collapsed, adUnitId = \(ad.adUnitIdentifier)")
    }

    // The following two methods are deprecated: reference https://support.axon.ai/en/max/ios/ad-formats/banner-and-mrec-ads for more details

    func didDisplay(_ ad: MAAd) {}

    func didHide(_ ad: MAAd) {}
}
