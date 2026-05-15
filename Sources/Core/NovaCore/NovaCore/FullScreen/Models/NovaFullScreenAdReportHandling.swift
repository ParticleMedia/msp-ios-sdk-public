//
//  NovaFullScreenAdReportHandling.swift
//  NovaCore
//

import Foundation
import UIKit

public struct NovaAdReportContext {
    public let advertiser: String?
    public let headline: String?
    public let body: String?
    public let adId: String
    public let adSetId: String
    public let adRequestId: String
    public let encryptedToken: String
    public let extra: [String: Any]

    public init(
        advertiser: String?,
        headline: String?,
        body: String?,
        adId: String,
        adSetId: String,
        adRequestId: String,
        encryptedToken: String,
        extra: [String: Any] = [:]
    ) {
        self.advertiser = advertiser
        self.headline = headline
        self.body = body
        self.adId = adId
        self.adSetId = adSetId
        self.adRequestId = adRequestId
        self.encryptedToken = encryptedToken
        self.extra = extra
    }
}

/// Report-flow contract used by full-screen Nova ads (interstitial and rewarded).
/// Adapter-layer types bridge each public report-handling protocol
/// (`InterstitialAdReportHandling`, `RewardedAdReportHandling`) into this Nova-internal
/// protocol so a single H5 → report flow exists for both formats.
public protocol NovaFullScreenAdReportHandling {
    func novaStartReportFlow(from presentingVC: UIViewController?, context: NovaAdReportContext)

    // optional methods
    func novaCanShowReportButton(with context: NovaAdReportContext) -> Bool
}

public extension NovaFullScreenAdReportHandling {
    func novaCanShowReportButton(with context: NovaAdReportContext) -> Bool { false }
}

/// Backwards-compatible alias for callers that pre-date the rename. New code should use
/// `NovaFullScreenAdReportHandling`.
public typealias NovaInterstitialAdReportHandling = NovaFullScreenAdReportHandling

extension NovaFullScreenAdItem {
    var novaAdReportContext: NovaAdReportContext {
        .init(
            advertiser: advertiser,
            headline: headline,
            body: body,
            adId: adId,
            adSetId: adSetId,
            adRequestId: requestId,
            encryptedToken: encryptedAdToken
        )
    }
}
