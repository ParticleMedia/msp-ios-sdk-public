//
//  NovaNativeAdVideoClearSubviewHandler.swift
//  NBNovaAdMedia
//
//  Created by Shanyu Li on 2025/8/6.
//

import Foundation
import UIKit

// MARK: - NovaNativeAdVideoClearSubviewHandler

final class NovaNativeAdVideoClearSubviewHandler: NSObject {}

// MARK: NovaNativeAdVideoSubviewHandler

extension NovaNativeAdVideoClearSubviewHandler: NovaNativeAdVideoSubviewHandler {
    func setup(on view: UIView) {}

    func sync(with state: NovaAdVideoState) {}

    func toggleAllSubViewVisibility(completion: ((_ currentHideStatus: Bool) -> Void)?) {}

    func removeViewsFromSuperview() {}
}
