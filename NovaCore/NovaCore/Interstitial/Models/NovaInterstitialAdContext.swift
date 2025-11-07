//
//  NovaInterstitialAdContext.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

import Foundation

// MARK: - NovaInterstitialAdContext

struct NovaInterstitialAdContext {
    // MARK: Lifecycle

    init(interstitialAd: NovaInterstitialAdItem, layout: NovaInterstitialAdLayout, tracingId: UUID?) {
        self.interstitialAd = interstitialAd
        self.layout = layout
        self.tracingId = tracingId
    }

    // MARK: Internal

    let interstitialAd: NovaInterstitialAdItem
    let layout: NovaInterstitialAdLayout
    let tracingId: UUID?
}

// MARK: - NovaInterstitialAdLayoutType

enum NovaInterstitialAdLayoutType {
    case horizontal(showTopRightCancelButton: Bool)
    case vertical(showTopRightCancelButton: Bool)
    case playable
    case twoPartPlayable
    case skOverlay(appStoreId: Int, thirdPartyTrackingURL: URL)
}

extension NovaInterstitialAdItem {
    var layoutTypeInInterstitial: NovaInterstitialAdLayoutType {
        switch mediaContent.adMedia {
        case .imagePlayable:
            return .playable
        case .videoPlayable:
            return .twoPartPlayable
        case .multipleImages, .multipleItems:
            return .horizontal(showTopRightCancelButton: false)
        case .image, .video:
            switch layoutStyle {
            case .horizontal:
                return .horizontal(showTopRightCancelButton: false)
            case .vertical:
                return .vertical(showTopRightCancelButton: false)
            case .downloadBanner:
                if case let .appInstall(appInstallModel) = adCtrType {
                    return .skOverlay(
                        appStoreId: appInstallModel.storeId,
                        thirdPartyTrackingURL: appInstallModel.fallbackWebModel.url
                    )
                }
                return .horizontal(showTopRightCancelButton: false)
            case .horizontalCancelTopRight:
                return .horizontal(showTopRightCancelButton: true)
            case .verticalCancelTopRight:
                return .vertical(showTopRightCancelButton: true)
            case .sponsor, .endCard:
                // TODO: lsy, 把之前实现的迁移过来，我没有太懂 end card 应该是什么样子的
                return .horizontal(showTopRightCancelButton: false)
            case .unknown:
                DebugLogger.ui.error("missing interstitial layout: \(self.adId)")
                return .horizontal(showTopRightCancelButton: false)
            }
        }
    }
}
