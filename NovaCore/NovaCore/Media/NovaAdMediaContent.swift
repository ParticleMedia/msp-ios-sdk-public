//
//  NovaAdMediaContent.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/8/28.
//

import Foundation

public class NovaAdVideoController {
    let videoView: NovaAdVideoView
    public var style: NovaAdVideoView.Style
    public var muted: Bool {
        didSet {
            videoView.muted = muted
        }
    }

    init(muted: Bool) {
        videoView = NovaAdVideoView()
        style = .clear
        self.muted = muted
    }

    func play() {
        videoView.play(with: .continueFromLast)
    }

    func pause() {
        videoView.pause()
    }

    func stop() {
        videoView.stop()
    }
}

public class NovaAdPlayableController {
    public enum RenderOption {
        case auto
        case imageOrVideo
        case playable
    }

    public var renderOption: RenderOption

    let playableView: NovaAdPlayableView

    init(renderOption: RenderOption) {
        self.renderOption = renderOption
        self.playableView = .init()
    }
}

public class NovaAdMediaContent {
    private enum Constants {
        static let verticalMediaRatio: CGFloat = 9.0 / 16.0
        static let horizontalMediaRatio: CGFloat = 1200.0 / 627.0
        static let carouselMinHeight: CGFloat = 283.0
        static let collectionMediaRatio: CGFloat = 6.0 / 5.0
        static let collectionMediaOffset: CGFloat = 4.0 / 3.0
    }

    public enum NovaAdMediaRenderRecommendation {
        /// height = width / aspectRatio
        case aspectRatio(CGFloat)
        /// height = width / aspectRatio + offset
        case aspectRatioAndOffset(CGFloat, CGFloat)
        case minHeight(CGFloat)
        case free
    }
    let adMedia: NovaAdMedia
    let discountTagInfo: NovaAdDiscountTagInfo?

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

    init(adMedia: NovaAdMedia, discountTagInfo: NovaAdDiscountTagInfo? = nil) {
        self.adMedia = adMedia
        self.discountTagInfo = discountTagInfo
    }
}
