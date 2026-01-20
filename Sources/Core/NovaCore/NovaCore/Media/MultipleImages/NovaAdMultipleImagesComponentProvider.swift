//
//  NovaAdMultipleImagesComponentProvider.swift
//  NBNovaAds
//
//  Created by Shanyu Li on 2024/8/5.
//

import Foundation

class NovaAdMultipleImagesComponentProvider {

    lazy var multipleImagesView: NovaAdMultipleImagesView = {
        let imagesView = NovaAdMultipleImagesView()
        imagesView.delegate = self
        return imagesView
    }()

    lazy var multipleImagesIndicator: NovaAdMultipleImagesIndicator = {
        let indicator = NovaAdMultipleImagesIndicator()
        return indicator
    }()

    func config(with mediaModel: NovaAdMultipleImagesMediaModel, actionContext: NovaAdMediaActionContext?) {
        multipleImagesView
            .render(with: mediaModel, actionContext: actionContext)
        multipleImagesIndicator
            .render(with: MultipleImagesIndicatorConfig(count: mediaModel.imageURLs.count, cornerRadius: 1.0))
    }
}

extension NovaAdMultipleImagesComponentProvider: NovaAdMultipleImagesViewDelegate {
    func multipleImagesView(_ imagesView: NovaAdMultipleImagesView, isAutoPlayingOn index: Int, progress: Float) {
        multipleImagesIndicator.setIndicator(to: index, progress: progress)
    }
}
