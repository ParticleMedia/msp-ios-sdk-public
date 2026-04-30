//
//  ApplovinMaxRewardedDelegateHandler.swift
//  ApplovinMaxAdapter
//

import AppLovinSDK
import Foundation
import MSPiOSCore

class ApplovinMaxRewardedDelegateHandler: NSObject, MARewardedAdDelegate {
    weak var adapter: ApplovinMaxAdapter?

    init(adapter: ApplovinMaxAdapter) {
        self.adapter = adapter
    }

    func didLoad(_ ad: MAAd) {
        MSPLogger.shared.info(
            message: "[Adapter: ApplovinMax] Rewarded ad loaded, adUnitId = \(ad.adUnitIdentifier)")
        DispatchQueue.main.async { [weak self] in
            guard let self, let adapter = self.adapter else { return }
            adapter.crid = ad.creativeIdentifier
            adapter.priceInDollar = ad.revenue

            let reward = Reward(type: "applovin", amount: 1)
            let rewardedAd = ApplovinMaxRewardedAd(
                adNetworkAdapter: adapter,
                reward: reward,
                maxRewardedAd: adapter.maxRewardedAd)
            adapter.mspRewardedAd = rewardedAd
            adapter.handleAdLoaded(mspAd: rewardedAd)
        }
    }

    func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        MSPLogger.shared.info(
            message:
                "[Adapter: ApplovinMax] Rewarded ad failed to load, adUnitId = \(adUnitIdentifier), error = \(error.message)"
        )
        adapter?.handleAdLoadFailed(error: error.message)
    }

    func didDisplay(_ ad: MAAd) {
        MSPLogger.shared.info(
            message: "[Adapter: ApplovinMax] Rewarded ad displayed, adUnitId = \(ad.adUnitIdentifier)")
        DispatchQueue.main.async { [weak self] in
            guard let self, let mspAd = self.adapter?.mspRewardedAd else { return }
            mspAd.handleAdDisplayed()
            self.adapter?.handleAdImpression(mspAd: mspAd)
        }
    }

    func didHide(_ ad: MAAd) {
        MSPLogger.shared.info(
            message: "[Adapter: ApplovinMax] Rewarded ad hidden, adUnitId = \(ad.adUnitIdentifier)")
        DispatchQueue.main.async { [weak self] in
            self?.adapter?.mspRewardedAd?.handleAdClosed()
        }
    }

    func didClick(_ ad: MAAd) {
        MSPLogger.shared.info(
            message: "[Adapter: ApplovinMax] Rewarded ad clicked, adUnitId = \(ad.adUnitIdentifier)")
        DispatchQueue.main.async { [weak self] in
            guard let self, let mspAd = self.adapter?.mspRewardedAd else { return }
            mspAd.handleAdClicked()
            self.adapter?.handleAdClicked(mspAd: mspAd)
        }
    }

    func didFail(toDisplay ad: MAAd, withError error: MAError) {
        MSPLogger.shared.error(
            tag: "Rewarded",
            message:
                "[Adapter: ApplovinMax] Rewarded ad failed to display, adUnitId = \(ad.adUnitIdentifier), error = \(error.message)"
        )
        adapter?.mspRewardedAd?.handleDisplayFailure(error: error)
    }

    func didRewardUser(for ad: MAAd, with reward: MAReward) {
        MSPLogger.shared.info(
            message:
                "[Adapter: ApplovinMax] Rewarded ad reward earned, adUnitId = \(ad.adUnitIdentifier), reward = \(reward.label):\(reward.amount)"
        )
        DispatchQueue.main.async { [weak self] in
            self?.adapter?.mspRewardedAd?.handleRewardEarned()
        }
    }
}
