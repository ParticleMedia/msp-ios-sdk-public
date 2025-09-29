//
//  ReportHandlerAdapter.swift
//  NovaAdapter
//
//  Created by Shanyu Li on 2025/9/29.
//

import UIKit
import MSPiOSCore
import NovaCore

final class ReportHandlerAdapter: NovaInterstitialAdReportHandling {

    private weak var outer: (any InterstitialAdReportHandling)?
    private weak var ad: InterstitialAd?

    init(outer: (any InterstitialAdReportHandling)?, ad: InterstitialAd) {
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
            "extra": context.extra
        ]
        outer?.startReportFlow(from: presentingVC, for: ad, metadata: metadata)
    }


    func novaCanShowReportButton(with context: NovaAdReportContext) -> Bool {
        guard let ad else { return false }
        return outer?.canShowReportButton(for: ad) ?? false
    }
}
