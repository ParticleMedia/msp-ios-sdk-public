//
//  NovaAdMultipleImagesMediaModel.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/7.
//

import Foundation

struct NovaAdMultipleImagesMediaModel {
    // MARK: Lifecycle

    init(imageURLs: [URL], adCtrType: AdCtrType, timerInterval: TimeInterval? = nil) {
        self.imageURLs = imageURLs
        self.adCtrType = adCtrType
        self.timerInterval = timerInterval
    }

    // MARK: Internal

    let imageURLs: [URL]
    let adCtrType: AdCtrType
    let timerInterval: TimeInterval?
}
