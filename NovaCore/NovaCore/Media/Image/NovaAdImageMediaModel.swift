//
//  NovaAdImageMediaModel.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/7.
//

import UIKit

struct NovaAdImageMediaModel {
    // MARK: Lifecycle

    init(
        resource: NovaAdImageResource,
        isImageClickable: Bool,
        adCtrType: AdCtrType,
        imageContentMode: UIView.ContentMode? = nil,
        isVerticalImage: Bool?,
        shouldShowImageBorder: Bool
    ) {
        self.resource = resource
        self.isImageClickable = isImageClickable
        self.adCtrType = adCtrType
        self.imageContentMode = imageContentMode
        self.isVerticalImage = isVerticalImage
        self.shouldShowImageBorder = shouldShowImageBorder
    }

    // MARK: Internal

    var resource: NovaAdImageResource
    let isImageClickable: Bool
    let adCtrType: AdCtrType
    let imageContentMode: UIView.ContentMode?
    let isVerticalImage: Bool?
    let shouldShowImageBorder: Bool
}
