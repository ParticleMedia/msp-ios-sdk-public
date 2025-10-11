//
//  NovaAdMediaContent.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/8/28.
//

import Foundation
import UIKit

public class NovaAdImageController {
    public var contentMode: UIView.ContentMode {
        get {
            imageView.contentMode
        }
        set {
            imageView.contentMode = newValue
        }
    }

    let imageView: NovaAdImageView

    init(contentMode: UIView.ContentMode? = nil) {
        imageView = NovaAdImageView()
        if let contentMode {
            imageView.contentMode = contentMode
        }
    }
}

// MARK: - NovaAdVideoController

public class NovaAdVideoController {
    // MARK: Lifecycle

    init(muted: Bool) {
        videoView = NovaAdVideoView()
        self.muted = muted
    }

    // MARK: Public

    public var style: NovaAdVideoView.Style {
        get {
            videoView.style
        }
        set {
            videoView.style = newValue
        }
    }

    public weak var delegate: NovaAdVideoViewDelegate? {
        get {
            videoView.delegate
        }
        set {
            videoView.delegate = newValue
        }
    }

    public var muted: Bool {
        get {
            videoView.muted
        }
        set {
            videoView.muted = newValue
        }
    }

    public func play() {
        videoView.play(with: .continueFromLast)
    }

    public func pause() {
        videoView.pause()
    }

    public func stop() {
        videoView.stop()
    }

    // MARK: Internal

    let videoView: NovaAdVideoView
}

// MARK: - NovaAdPlayableController

public class NovaAdPlayableController {
    // MARK: Lifecycle

    init(renderOption: RenderOption) {
        self.renderOption = renderOption
        self.playableView = .init()
    }

    // MARK: Public

    public enum RenderOption {
        case auto
        case imageOrVideo
        case playable
    }

    public var renderOption: RenderOption

    // MARK: Internal

    let playableView: NovaAdPlayableView
}

// MARK: - NovaAdMediaContent

public class NovaAdMediaContent {
    // MARK: Lifecycle

    init(adMedia: NovaAdMedia, discountTagInfo: NovaAdDiscountTagInfo? = nil) {
        self.adMedia = adMedia
        self.discountTagInfo = discountTagInfo
    }

    // MARK: Public

    public enum NovaAdMediaRenderRecommendation {
        /// height = width / aspectRatio
        case aspectRatio(CGFloat)
        /// height = width / aspectRatio + offset
        case aspectRatioAndOffset(CGFloat, CGFloat)
        case minHeight(CGFloat)
        case free
    }

    public lazy var imageController: NovaAdImageController? = {
        switch adMedia {
        case .image(let model), .imagePlayable(let model, _):
            return .init(contentMode: model.imageContentMode)
        default:
            return nil
        }
    }()

    public lazy var videoController: NovaAdVideoController? = {
        switch adMedia {
        case .video(let model):
            return .init(muted: model.videoInfo.isMute)
        case .videoPlayable(let videoModel, _):
            return .init(muted: videoModel.videoInfo.isMute)
        case .image, .multipleItems, .multipleImages, .imagePlayable:
            return nil
        }
    }()

    public lazy var playableController: NovaAdPlayableController? = {
        switch adMedia {
        case .imagePlayable, .videoPlayable:
            return .init(renderOption: .auto)
        default:
            return nil
        }
    }()

    public var renderRecommendation: NovaAdMediaRenderRecommendation? {
        switch adMedia {
        case .image(let model):
            if let isVerticalImage = model.isVerticalImage {
                let aspectRatio = isVerticalImage ? Constants.verticalMediaRatio : Constants.horizontalMediaRatio
                return .aspectRatio(aspectRatio)
            } else {
                return nil
            }
        case .video(let model):
            let aspectRatio = model.videoInfo.isVertical ? Constants.verticalMediaRatio : Constants.horizontalMediaRatio
            return .aspectRatio(aspectRatio)
        case .multipleImages:
            return .free
        case .multipleItems(let model):
            switch model.info.style {
            case .carousel:
                return .minHeight(Constants.carouselMinHeight)
            case .collection:
                return .aspectRatioAndOffset(Constants.collectionMediaRatio, Constants.collectionMediaOffset)
            }
        case .imagePlayable(let imageModel, let playableModel):
            switch playableController?.renderOption {
            case .auto, .none:
                switch playableModel.layout {
                case .showMedia, .twoPart:
                    if let isVerticalImage = imageModel.isVerticalImage {
                        return isVerticalImage ?
                            .aspectRatio(Constants.verticalMediaRatio) :
                            .aspectRatio(Constants.horizontalMediaRatio)
                    } else {
                        return nil
                    }
                case .showPlayable:
                    return .free
                }
            case .imageOrVideo:
                if let isVerticalImage = imageModel.isVerticalImage {
                    return isVerticalImage ?
                        .aspectRatio(Constants.verticalMediaRatio) :
                        .aspectRatio(Constants.horizontalMediaRatio)
                } else {
                    return nil
                }
            case .playable:
                return .free
            }
        case .videoPlayable(let videoModel, let playableModel):
            switch playableController?.renderOption {
            case .auto, .none:
                switch playableModel.layout {
                case .showMedia, .twoPart:
                    return videoModel.videoInfo.isVertical ?
                        .aspectRatio(Constants.verticalMediaRatio) :
                        .aspectRatio(Constants.horizontalMediaRatio)
                case .showPlayable:
                    return .free
                }
            case .imageOrVideo:
                return videoModel.videoInfo.isVertical ?
                    .aspectRatio(Constants.verticalMediaRatio) :
                    .aspectRatio(Constants.horizontalMediaRatio)
            case .playable:
                return .free
            }
        }
    }

    public var mediaType: NovaAdMediaType {
        switch adMedia {
        case .image:
            return .image
        case .video:
            return .video
        case .multipleImages:
            return .multipleImages
        case .multipleItems:
            return .multipleItems
        case .imagePlayable, .videoPlayable:
            return .playable
        }
    }

    // MARK: Internal

    let adMedia: NovaAdMedia
    let discountTagInfo: NovaAdDiscountTagInfo?

    // MARK: Private

    private enum Constants {
        static let verticalMediaRatio: CGFloat = 9.0 / 16.0
        static let horizontalMediaRatio: CGFloat = 1200.0 / 627.0
        static let carouselMinHeight: CGFloat = 283.0
        static let collectionMediaRatio: CGFloat = 6.0 / 5.0
        static let collectionMediaOffset: CGFloat = 4.0 / 3.0
    }
}
