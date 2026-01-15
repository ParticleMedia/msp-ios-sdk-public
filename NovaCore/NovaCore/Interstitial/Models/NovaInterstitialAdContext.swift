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

    init(interstitialAd: NovaInterstitialAdItem, layout: NovaInterstitialAdLayout, tracingId: UUID?, pageIndex: Int? = nil) {
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
    case html(model: NovaAdHtmlMediaModel)
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
                if case let .appInstall(appInstallModel) = adCtrType, supportOCPM {
                    return .skOverlay(
                        appStoreId: appInstallModel.storeId,
                        thirdPartyTrackingURL: appInstallModel.fallbackWebModel.url
                    )
                } else {
                    return .vertical(showTopRightCancelButton: false)
                }
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
        case let .html(model):
            return .html(model: model)
        }
    }
}

// MARK: - NovaInterstitialSubviewError

enum NovaInterstitialSubviewError: LocalizedError {
    case layoutNotSupported(layout: NovaInterstitialAdLayout)
    case playableInfoNotFound

    func errorDescription() -> String? {
        switch self {
        case .layoutNotSupported(let layout):
            return "\(layout.rawValue) layout is not supported in app open ad"
        case .playableInfoNotFound:
            return "Playable info not found"
        }
    }
}
