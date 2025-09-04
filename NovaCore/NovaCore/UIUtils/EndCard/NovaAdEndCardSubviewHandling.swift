//
//  NovaAdEndCardSubviewHandling.swift
//
//  Created by Shanyu Li on 2025/2/13.
//

import Foundation
import UIKit

// MARK: - NovaAdEndCardSubviewBehaviorDelegate

protocol NovaAdEndCardSubviewBehaviorDelegate: AnyObject {
    func didTapCloseButton()

    func didTapWatchAgainButton()
}

// MARK: - NovaAdEndCardSubviewHandling

protocol NovaAdEndCardSubviewHandling {
    func set(on parentView: UIView)

    func config(with model: NovaAdEndCardViewModel)

    func clickableViews() -> [UIView]
}

// MARK: - NovaAdEndCardViewModel

struct NovaAdEndCardViewModel {
    // MARK: Lifecycle

    private init(
        style: NovaAdEndCard.Style,
        iconUrl: URL?,
        advertiser: String?,
        description: String?,
        body: String?,
        ctaText: String?,
        isAppInstall: Bool
    ) {
        self.style = style
        self.iconUrl = iconUrl
        self.advertiser = advertiser
        self.description = description
        self.body = body
        self.ctaText = ctaText
        self.isAppInstall = isAppInstall
    }

    // MARK: Internal

    let style: NovaAdEndCard.Style
    let iconUrl: URL?
    let advertiser: String?
    let description: String?
    let body: String?
    let ctaText: String?
    let isAppInstall: Bool

    static func create(from ad: NovaNativeBaseAd, style: NovaAdEndCard.Style) -> Self {
        let isAppInstall = {
            if case .appInstall = ad.adCtrType {
                return true
            } else {
                return false
            }
        }()

        return .init(
            style: style,
            iconUrl: ad.appInfo?.appIconUrl ?? URL(string: ad.iconUrlStr ?? ""),
            advertiser: ad.appInfo?.appName ?? ad.advertiser,
            description: ad.headline,
            body: ad.body,
            ctaText: ad.callToAction,
            isAppInstall: isAppInstall
        )
    }
}

// MARK: - NovaAdEndCardSubviewHandlerCreator

enum NovaAdEndCardSubviewHandlerCreator {
    static func create(
        with style: NovaAdEndCard.Style,
        delegate: any NovaAdEndCardSubviewBehaviorDelegate
    ) -> any NovaAdEndCardSubviewHandling {
        switch style {
        case .horizontalDefault:
            return HorizontalEndCardSubviewHandler(delegate: delegate)
        case .verticalDefault:
            return VerticalEndCardSubviewHandler(delegate: delegate)
        case .immersiveDefault:
            return ImmersiveEndCardSubviewHandler(delegate: delegate)
        case .center:
            return CenterEndCardSubviewHandler(delegate: delegate)
        }
    }
}

// MARK: - NovaEndCardStylable

protocol NovaEndCardStylable {
    var endCardStyle: NovaAdEndCard.Style? { get }
}

// MARK: - NovaNativeAdItem + NovaEndCardStylable

extension NovaNativeAdItem: NovaEndCardStylable {
    var endCardStyle: NovaAdEndCard.Style? {
        switch layoutStyle {
        case .horizontal, .sponsor:
            return .horizontalDefault
        case .vertical, .taller, .interscroller:
            return .verticalDefault
        case .unknown, .carousel, .collection:
            return nil
        }
    }
}

// MARK: - NovaInterstitialAdItem + NovaEndCardStylable

extension NovaInterstitialAdItem: NovaEndCardStylable {
    var endCardStyle: NovaAdEndCard.Style? {
        switch layoutStyle {
        case .vertical, .verticalCancelTopRight, .endCard:
            return .center
        case .horizontal, .horizontalCancelTopRight, .sponsor, .unknown:
            return nil
        }
    }
}

extension NovaNativeBaseAd {
    func getEndCardStyle() -> NovaAdEndCard.Style? {
        (self as? NovaEndCardStylable)?.endCardStyle
    }
}
