//
//  RewardedReportHandlerAdapter.swift
//  NovaAdapter
//

import MSPiOSCore
import NovaCore
import UIKit

/// Bridges the public `RewardedAdReportHandling` protocol to the Nova-internal
/// `NovaFullScreenAdReportHandling`. Mirrors `Interstitial/ReportHandlerAdapter`.
final class RewardedReportHandlerAdapter: NovaFullScreenAdReportHandling {
    private weak var outer: (any RewardedAdReportHandling)?
    private weak var ad: RewardedAd?

    init(outer: (any RewardedAdReportHandling)?, ad: RewardedAd) {
        self.outer = outer
        self.ad = ad
    }

    func novaStartReportFlow(from presentingVC: UIViewController?, context: NovaAdReportContext) {
        guard let ad else { return }
        let metadata: [String: Any] = [
            "advertiser": context.advertiser ?? "",
            "headline": context.headline ?? "",
            "body": context.body ?? "",
            "adId": context.adId,
            "adSetId": context.adSetId,
            "adRequestId": context.adRequestId,
            "encryptedToken": context.encryptedToken,
            "extra": context.extra,
        ]
        outer?.startReportFlow(from: presentingVC, for: ad, metadata: metadata)
    }

    func novaCanShowReportButton(with context: NovaAdReportContext) -> Bool {
        guard let ad else { return false }
        return outer?.canShowReportButton(for: ad) ?? false
    }
}
