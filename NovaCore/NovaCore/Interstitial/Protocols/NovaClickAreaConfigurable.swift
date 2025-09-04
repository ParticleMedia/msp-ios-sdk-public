//
//  NovaClickAreaConfigurable.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/9/2.
//

import UIKit

protocol NovaClickAreaConfigurable: AnyObject {
    // subviews
    var title: UILabel? { get }
    var body: UILabel? { get }
    var advertiser: UILabel? { get }
    var adTag: UILabel? { get }
    var cta: UIButton? { get }
    var icon: UIImageView? { get }
    // configuration
    var clickableComponents: [NovaClickableComponent]? { get }
}

extension NovaClickAreaConfigurable {
    func getClickableViewsFromConfiguration() -> [UIView]? {
        guard let clickableComponents, !clickableComponents.isEmpty else {
            return nil
        }
        var clickableViews: [UIView] = []
        for clickableComponent in clickableComponents {
            switch clickableComponent {
            case .title:
                if let title {
                    clickableViews.append(title)
                }
            case .body:
                if let body {
                    clickableViews.append(body)
                }
            case .media:
                // TODO: lsy, media view 是不能直接加上点击的，因为有一些比如 carousel 并不是整个 media 区域都能点
                break
            case .advertiserName:
                if let advertiser {
                    clickableViews.append(advertiser)
                }
            case .adTag:
                if let adTag {
                    clickableViews.append(adTag)
                }
            case .cta:
                if let cta {
                    clickableViews.append(cta)
                }
            case .icon:
                if let icon {
                    clickableViews.append(icon)
                }
            case .all:
                return [
                    title,
                    body,
                    advertiser,
                    adTag,
                    cta,
                    icon
                ].compactMap { $0 }
            }
        }
        return clickableViews
    }
}
