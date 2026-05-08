//
//  ApplovinMaxInterstitialDelegateHandler.swift
//  ApplovinMaxAdapter
//

import AppLovinSDK
import Foundation
import MSPiOSCore

class ApplovinMaxInterstitialDelegateHandler: NSObject, MAAdDelegate {
    weak var adapter: ApplovinMaxAdapter?

    init(adapter: ApplovinMaxAdapter) {
        self.adapter = adapter
    }

    func didLoad(_ ad: MAAd) {
        MSPLogger.shared.info(
            message: "[Adapter: ApplovinMax] Interstitial ad loaded, adUnitId = \(ad.adUnitIdentifier)")
        DispatchQueue.main.async { [weak self] in
            guard let self, let adapter = self.adapter else { return }
            adapter.crid = ad.creativeIdentifier
            adapter.priceInDollar = ad.revenue

            let interstitialAd = ApplovinMaxInterstitialAd(adNetworkAdapter: adapter)
            interstitialAd.maxInterstitialAd = adapter.interstitialAd
            adapter.mspInterstitialAd = interstitialAd
            adapter.handleAdLoaded(mspAd: interstitialAd)
        }
    }

    func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        MSPLogger.shared.info(
            message:
                "[Adapter: ApplovinMax] Interstitial ad failed to load, adUnitId = \(adUnitIdentifier), error = \(error.message)"
        )
        adapter?.handleAdLoadFailed(error: error.message)
    }

    func didDisplay(_ ad: MAAd) {
        MSPLogger.shared.info(
            message: "[Adapter: ApplovinMax] Interstitial ad displayed, adUnitId = \(ad.adUnitIdentifier)")
        if let mspAd = adapter?.mspInterstitialAd {
            adapter?.handleAdImpression(mspAd: mspAd)
        }
    }

    func didHide(_ ad: MAAd) {
        MSPLogger.shared.info(
            message: "[Adapter: ApplovinMax] Interstitial ad hidden, adUnitId = \(ad.adUnitIdentifier)")
        DispatchQueue.main.async { [weak self] in
            guard let self, let adapter = self.adapter else { return }
            if let mspAd = adapter.mspInterstitialAd {
                adapter.adListener?.onAdDismissed(ad: mspAd)
                adapter.sendDismissAdEvent()
            }
        }
    }

    func didClick(_ ad: MAAd) {
        MSPLogger.shared.info(
            message: "[Adapter: ApplovinMax] Interstitial ad clicked, adUnitId = \(ad.adUnitIdentifier)")
        if let mspAd = adapter?.mspInterstitialAd {
            adapter?.handleAdClicked(mspAd: mspAd)
        }
    }

    func didFail(toDisplay ad: MAAd, withError error: MAError) {
        MSPLogger.shared.error(
            tag: "Interstitial",
            message:
                "[Adapter: ApplovinMax] Interstitial failed to display, adUnitId = \(ad.adUnitIdentifier), error = \(error.message)"
        )
    }
}
