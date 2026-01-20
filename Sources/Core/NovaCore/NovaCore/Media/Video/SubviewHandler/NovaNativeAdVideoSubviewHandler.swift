//
//  NovaNativeAdVideoSubviewHandler.swift
//  Pods
//
//  Created by Shanyu Li on 2025/2/5.
//

import CoreMedia
import UIKit

protocol NovaNativeAdVideoSubviewHandler {
    func setup(on view: UIView)

    func sync(with state: NovaAdVideoState)

    func removeViewsFromSuperview()

    // Optional
    func config(with videoModel: NovaAdVideoMediaModel)

    func toggleAllSubViewVisibility(completion: ((_ currentHideStatus: Bool) -> Void)?)

    func tapVideo(on view: UIView, at location: CGPoint, isPlaying: Bool)
}

extension NovaNativeAdVideoSubviewHandler {
    func config(with videoModel: NovaAdVideoMediaModel) {}

    func toggleAllSubViewVisibility(completion: ((_ currentHideStatus: Bool) -> Void)?) {}

    func tapVideo(on view: UIView, at location: CGPoint, isPlaying: Bool) {}
}
