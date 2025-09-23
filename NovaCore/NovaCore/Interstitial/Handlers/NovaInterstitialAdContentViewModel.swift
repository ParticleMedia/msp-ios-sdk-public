//
//  NovaInterstitialAdSubviewHandler.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

import Foundation
import UIKit
@_implementationOnly import SnapKit


// MARK: - NovaInterstitialAdContentViewModel

struct NovaInterstitialAdContentViewModel {
    // MARK: Lifecycle

    init(interstitialAd: NovaInterstitialAdItem, vcEmbedded: UIViewController) {
        self.advertiserLogoUrlStr = interstitialAd.iconUrlStr
        self.advertiserText = interstitialAd.advertiser?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.headlineText = interstitialAd.headline?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bodyText = interstitialAd.body?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.callToAction = interstitialAd.callToAction
        self.encryptedAdToken = interstitialAd.encryptedAdToken
        self.adId = interstitialAd.adId
        self.adOpportunityId = interstitialAd.adOpportunityID
        self.vcEmbedded = vcEmbedded
    }

    // MARK: Internal

    let advertiserLogoUrlStr: String?
    let advertiserText: String?
    let headlineText: String?
    let bodyText: String?
    let callToAction: String?
    let encryptedAdToken: String
    let adId: String
    let adOpportunityId: UUID?
    let vcEmbedded: UIViewController
}
