//
//  NovaAdMediaContent.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/8/28.
//

// MARK: - NovaMediaElementLayout

import Foundation
import MSPiOSCore
import UIKit

public struct NovaMediaElementLayout: Equatable {
    public let safeAreaInsets: UIEdgeInsets
    public let exclusionRects: [CGRect]
    let showBottomShadow: Bool
    var showTapToTry: Bool

    public init(
        safeAreaInsets: UIEdgeInsets = .zero,
        exclusionRects: [CGRect] = [],
        showBottomShadow: Bool = false,
        showTapToTry: Bool = true
    ) {
        self.safeAreaInsets = safeAreaInsets
        self.exclusionRects = exclusionRects
        self.showBottomShadow = showBottomShadow
        self.showTapToTry = showTapToTry
    }
}

public class NovaAdImageController {
    public weak var delegate: NovaAdImageViewDelegate? {
        get {
            imageView.delegate
        }
        set {
            imageView.delegate = newValue
        }
    }

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
    weak var mediaContent: NovaAdMediaContent? {
        didSet {
            videoView.mediaContent = mediaContent
        }
    }
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

    public weak var delegate: NovaAdPlayableViewDelegate? {
        get {
            playableView.delegate
        }
        set {
            playableView.delegate = newValue
        }
    }

    // MARK: Internal

    let playableView: NovaAdPlayableView
}

// MARK: - NovaAdMediaContent

public class NovaAdMediaContent {
    // MARK: Lifecycle

    init(
        adMedia: NovaAdMedia, discountTagInfo: NovaAdDiscountTagInfo? = nil,
        elementLayout: NovaMediaElementLayout? = nil
    ) {
        self.adMedia = adMedia
        self.discountTagInfo = discountTagInfo
        self.elementLayout = elementLayout
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
        let controller: NovaAdVideoController?
        switch adMedia {
        case .video(let model):
            controller = .init(muted: model.videoInfo.isMute)
        case .videoPlayable(let videoModel, _):
            controller = .init(muted: videoModel.videoInfo.isMute)
        case .image, .multipleItems, .multipleImages, .imagePlayable, .html:
            return nil
        }
        controller?.mediaContent = self
        return controller
    }()

    public lazy var playableController: NovaAdPlayableController? = {
        switch adMedia {
        case .imagePlayable, .videoPlayable:
            let controller = NovaAdPlayableController(renderOption: .auto)
            return controller
        default:
            return nil
        }
    }()

    public var renderRecommendation: NovaAdMediaRenderRecommendation? {
        switch adMedia {
        case .image(let model):
            switch model.imageLayoutOrientation {
            case .horizontal:
                return .aspectRatio(Constants.horizontalMediaRatio)
            case .vertical:
                return .aspectRatio(Constants.verticalMediaRatio)
            case .unknown:
                return .free
            }
        case .video(let model):
            switch model.videoLayoutOrientation {
            case .horizontal:
                return .aspectRatio(Constants.horizontalMediaRatio)
            case .vertical:
                return .aspectRatio(Constants.verticalMediaRatio)
            case .unknown:
                return .free
            }
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
                    switch imageModel.imageLayoutOrientation {
                    case .horizontal:
                        return .aspectRatio(Constants.horizontalMediaRatio)
                    case .vertical:
                        return .aspectRatio(Constants.verticalMediaRatio)
                    case .unknown:
                        return .free
                    }
                case .showPlayable:
                    return .free
                }
            case .imageOrVideo:
                switch imageModel.imageLayoutOrientation {
                case .horizontal:
                    return .aspectRatio(Constants.horizontalMediaRatio)
                case .vertical:
                    return .aspectRatio(Constants.verticalMediaRatio)
                case .unknown:
                    return .free
                }
            case .playable:
                return .free
            }
        case .videoPlayable(let videoModel, let playableModel):
            switch playableController?.renderOption {
            case .auto, .none:
                switch playableModel.layout {
                case .showMedia, .twoPart:
                    switch videoModel.videoLayoutOrientation {
                    case .horizontal:
                        return .aspectRatio(Constants.horizontalMediaRatio)
                    case .vertical:
                        return .aspectRatio(Constants.verticalMediaRatio)
                    case .unknown:
                        return .free
                    }
                case .showPlayable:
                    return .free
                }
            case .imageOrVideo:
                switch videoModel.videoLayoutOrientation {
                case .horizontal:
                    return .aspectRatio(Constants.horizontalMediaRatio)
                case .vertical:
                    return .aspectRatio(Constants.verticalMediaRatio)
                case .unknown:
                    return .free
                }
            case .playable:
                return .free
            }
        case .html:
            return .free
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
        case .imagePlayable(_, let playableModel):
            return playableModel.layout == .showMedia ? .image : .playable
        case .videoPlayable(_, let playableModel):
            return playableModel.layout == .showMedia ? .video : .playable
        case .html:
            return .html
        }
    }

    public var elementLayout: NovaMediaElementLayout?

    // MARK: Internal

    var adMedia: NovaAdMedia
    let discountTagInfo: NovaAdDiscountTagInfo?

    // MARK: - Video State Sync

    func updateVideoState(_ state: NovaAdVideoState?) {
        switch adMedia {
        case .video(let model):
            model.videoInfo.state = state
        case .videoPlayable(let videoModel, _):
            videoModel.videoInfo.state = state
        default:
            break
        }
    }

    // MARK: Private

    private enum Constants {
        static let verticalMediaRatio: CGFloat = 9.0 / 16.0
        static let horizontalMediaRatio: CGFloat = 1200.0 / 627.0
        static let carouselMinHeight: CGFloat = 283.0
        static let collectionMediaRatio: CGFloat = 6.0 / 5.0
        static let collectionMediaOffset: CGFloat = 4.0 / 3.0
    }
}
