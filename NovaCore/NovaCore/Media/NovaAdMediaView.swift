//
//  NovaAdMediaView.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/7.
//

import UIKit

// MARK: - NovaAdMediaViewDelegate

public protocol NovaAdMediaViewDelegate: AnyObject {
    func mediaViewPlayingDidEndPlaying()

    func mediaViewDidFinishFirstLoop()
}

// MARK: - NovaAdMediaView

public final class NovaAdMediaView: UIView {
    // MARK: Lifecycle

    // MARK: - Initializer

    public init(delegate: (any NovaAdMediaViewDelegate)? = nil) {
        super.init(frame: .zero)

        self.delegate = delegate
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Private

    private var mediaContent: NovaAdMediaContent?
    private weak var delegate: (any NovaAdMediaViewDelegate)?

    private lazy var imageView: NovaAdImageView = .init()

    private lazy var videoView: NovaAdVideoView = {
        mediaContent?.videoController?.videoView ?? .init()
    }()

    private lazy var multipleImagesComponentsProvider: NovaAdMultipleImagesComponentProvider = .init()

    private lazy var playableView: NovaAdPlayableView = {
        mediaContent?.playableController?.playableView ?? .init()
    }()

    private var currentView: UIView?

    private lazy var discountTag: NovaAdDiscountTag = .init()
}

// MARK: - methods

extension NovaAdMediaView {
    func config(
        with mediaContent: NovaAdMediaContent,
        actionContext: NovaAdMediaActionContext,
        iabReporter: IABMetricReporter? = nil,
        completion: @escaping (() -> Void) = {}
    ) {
        self.mediaContent = mediaContent
        if !adMediaAndCurrentViewTypeMatches(mediaContent) {
            currentView?.removeFromSuperview()
            let newMediaView: UIView = {
                switch mediaContent.adMedia {
                case .image:
                    return self.imageView
                case .video:
                    return self.videoView
                case .multipleImages:
                    self.multipleImagesComponentsProvider.multipleImagesView
                        .addSubview(self.multipleImagesComponentsProvider.multipleImagesIndicator)
                    self.multipleImagesComponentsProvider.multipleImagesIndicator.snp.makeConstraints { make in
                        make.directionalHorizontalEdges.equalToSuperview().inset(16.0)
                        make.bottom.equalToSuperview()
                        make.height.equalTo(2.0)
                    }
                    return self.multipleImagesComponentsProvider.multipleImagesView
                case .multipleItems(let model):
                    return NovaAdMultipleItemsViewProvider.getMultipleItemsView(with: model)
                case .imagePlayable(_, let playableModel):
                    switch mediaContent.playableController?.renderOption {
                    case .auto, .none:
                        switch playableModel.layout {
                        case .showMedia, .twoPart:
                            return self.imageView
                        case .showPlayable:
                            return self.playableView
                        }
                    case .imageOrVideo:
                        return self.imageView
                    case .playable:
                        return self.playableView
                    }
                case .videoPlayable(_, let playableModel):
                    switch mediaContent.playableController?.renderOption {
                    case .auto, .none:
                        switch playableModel.layout {
                        case .showMedia, .twoPart:
                            return self.videoView
                        case .showPlayable:
                            return self.playableView
                        }
                    case .imageOrVideo:
                        return self.videoView
                    case .playable:
                        return self.playableView
                    }
                }
            }()
            addSubview(newMediaView)
            newMediaView.snp.makeConstraints { make in
                make.directionalEdges.equalToSuperview()
            }
            currentView = newMediaView
        }
        switch mediaContent.adMedia {
        case .image(let model):
            imageView.config(with: model, actionContext: actionContext, completion: completion)
        case .video(let model):
            videoView.resetStyle(mediaContent.videoController?.style)
            videoView.config(with: model, actionContext: actionContext, iabReporter: iabReporter)
        case .multipleImages(let model):
            multipleImagesComponentsProvider.config(with: model, actionContext: actionContext)
        case .multipleItems(let model):
            (currentView as? AnyMultipleItemsView)?.config(
                with: model,
                actionContext: actionContext,
                completion: completion
            )
        case .imagePlayable(let imageModel, let playableModel):
            let renderOption = mediaContent.playableController?.renderOption
            let layout = playableModel.layout
            switch (renderOption, layout) {
            case (.auto, .showMedia), (.auto, .twoPart), (.none, .showMedia), (.none, .twoPart), (.imageOrVideo, _):
                imageView.config(with: imageModel, actionContext: actionContext, completion: completion)
            case (.auto, .showPlayable), (.none, .showPlayable), (.playable, _):
                playableView.config(with: playableModel.playableActionModel, actionContext: actionContext)
            }
        case .videoPlayable(let videoModel, let playableModel):
            let renderOption = mediaContent.playableController?.renderOption
            let layout = playableModel.layout
            switch (renderOption, layout) {
            case (.auto, .showMedia), (.auto, .twoPart), (.none, .showMedia), (.none, .twoPart), (.imageOrVideo, _):
                videoView.config(with: videoModel, actionContext: actionContext, iabReporter: iabReporter)
            case (.auto, .showPlayable), (.none, .showPlayable), (.playable, _):
                playableView.config(with: playableModel.playableActionModel, actionContext: actionContext)
            }
        }

        if let discountTagInfo = mediaContent.discountTagInfo {
            addSubview(discountTag)
            discountTag.config(with: discountTagInfo.style)
            discountTag.setupNormalLayout(on: self, with: discountTagInfo)
        }
    }

    func prepareForReuse() {
        videoView.isHidden = true
        videoView.prepareForReuse()

        discountTag.removeFromSuperview()
    }
}

private extension NovaAdMediaView {
    func adMediaAndCurrentViewTypeMatches(_ mediaContent: NovaAdMediaContent) -> Bool {
        switch mediaContent.adMedia {
        case .image:
            return currentView is NovaAdImageView
        case .video:
            return currentView is NovaAdVideoView
        case .multipleItems:
            return currentView is AnyMultipleItemsView
        case .multipleImages:
            return currentView is NovaAdMultipleImagesView
        case .imagePlayable(_, let playableModel):
            switch mediaContent.playableController?.renderOption {
            case .auto:
                switch playableModel.layout {
                case .showMedia, .twoPart:
                    return currentView is NovaAdImageView
                case .showPlayable:
                    return currentView is NovaAdPlayableView
                }
            case .imageOrVideo:
                return currentView is NovaAdImageView
            case .playable:
                return currentView is NovaAdPlayableView
            case nil:
                return false
            }
        case .videoPlayable(_, let playableModel):
            switch mediaContent.playableController?.renderOption {
            case .auto:
                switch playableModel.layout {
                case .showMedia, .twoPart:
                    return currentView is NovaAdVideoView
                case .showPlayable:
                    return currentView is NovaAdPlayableView
                }
            case .imageOrVideo:
                return currentView is NovaAdVideoView
            case .playable:
                return currentView is NovaAdPlayableView
            case nil:
                return false
            }
        }
    }
}

extension NovaAdMediaView: NovaAdVideoViewDelegate {
    func videoViewPlayingDidEndPlaying() {
        delegate?.mediaViewPlayingDidEndPlaying()
    }

    func videoViewCurrentTimeDidChange(loopCount: Int, currentTime: TimeInterval, videoLength: TimeInterval) {
        if (loopCount == 0 && currentTime >= videoLength - 0.01) || (loopCount == 1 && currentTime <= 0.01) {
            delegate?.mediaViewDidFinishFirstLoop()
        }
    }
}
