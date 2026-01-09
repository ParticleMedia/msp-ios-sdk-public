//
//  NovaAdMediaView.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/7.
//

import UIKit
internal import Lottie
@_implementationOnly import SnapKit

// MARK: - NovaAdMediaView

public final class NovaAdMediaView: UIView {
    // MARK: Lifecycle

    // MARK: - Initializer

    init() {
        super.init(frame: .zero)
    }

    deinit {
        cleanupBusinessSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Private

    private var mediaContent: NovaAdMediaContent?

    private var imageView: NovaAdImageView {
        if let imageView = mediaContent?.imageController?.imageView {
            return imageView
        } else {
            let newImageController = NovaAdImageController()
            mediaContent?.imageController = newImageController
            return newImageController.imageView
        }
    }

    private var videoView: NovaAdVideoView {
        if let videoView = mediaContent?.videoController?.videoView {
            return videoView
        } else {
            let newVideoController = NovaAdVideoController(muted: true)
            mediaContent?.videoController = newVideoController
            return newVideoController.videoView
        }
    }

    private lazy var multipleImagesComponentsProvider: NovaAdMultipleImagesComponentProvider = .init()

    private var playableView: NovaAdPlayableView {
        if let playableView = mediaContent?.playableController?.playableView {
            return playableView
        } else {
            let newPlayableController = NovaAdPlayableController(renderOption: .auto)
            mediaContent?.playableController = newPlayableController
            return newPlayableController.playableView
        }
    }

    private var currentView: UIView?

    private lazy var discountTag: NovaAdDiscountTag = .init()

    private lazy var tapToTryAnimationView: LottieAnimationView? = {
        let view = LottieAnimationView()
        if let animationPath = NovaResource.getLottieResourceURL("tap_to_try")?.path {
            DebugLogger.data.info("load lottie file success")
            view.isUserInteractionEnabled = false
            view.animation = LottieAnimation.filepath(animationPath)
            view.loopMode = .loop
            view.adClickArea = .tap_to_try
            return view
        } else {
            DebugLogger.data.error("can not load lottie file")
            return nil
        }
    }()

    private lazy var tapToTryStaticView: NovaAdTapToTryStaticView = {
        let view = NovaAdTapToTryStaticView()
        view.isUserInteractionEnabled = false
        return view
    }()
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
        currentView?.removeFromSuperview()
        let newMediaView: UIView? = {
            switch mediaContent.adMedia {
            case .image:
                return self.imageView
            case .video:
                return self.videoView
            case .multipleImages:
                self.multipleImagesComponentsProvider = NovaAdMultipleImagesComponentProvider()
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
            case .html:
                return nil
            }
        }()
        if let newMediaView = newMediaView {
            addSubview(newMediaView)
            newMediaView.snp.makeConstraints { make in
                make.directionalEdges.equalToSuperview()
            }
            currentView = newMediaView
            currentView?.adClickArea = .media
        }

        tapToTryAnimationView?.removeFromSuperview()
        tapToTryStaticView.removeFromSuperview()
        discountTag.removeFromSuperview()
        
        let showBottomShadow = mediaContent.elementLayout?.showBottomShadow ?? false
        
        switch mediaContent.adMedia {
        case .image(let model):
            imageView.config(with: model, actionContext: actionContext, completion: completion, showBottomShadow: showBottomShadow)
        case .video(let model):
            videoView.config(with: model, actionContext: actionContext, iabReporter: iabReporter, showBottomShadow: showBottomShadow)
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
                imageView.config(with: imageModel, actionContext: actionContext, completion: completion, showBottomShadow: showBottomShadow)
                setupTapToTry(with: playableModel)
            case (.auto, .showPlayable), (.none, .showPlayable), (.playable, _):
                playableView.config(with: playableModel.playableActionModel, actionContext: actionContext)
            }
        case .videoPlayable(let videoModel, let playableModel):
            let renderOption = mediaContent.playableController?.renderOption
            let layout = playableModel.layout
            switch (renderOption, layout) {
            case (.auto, .showMedia), (.auto, .twoPart), (.none, .showMedia), (.none, .twoPart), (.imageOrVideo, _):
                videoView.config(with: videoModel, actionContext: actionContext, iabReporter: iabReporter, showBottomShadow: showBottomShadow)
                setupTapToTry(with: playableModel)
            case (.auto, .showPlayable), (.none, .showPlayable), (.playable, _):
                playableView.config(with: playableModel.playableActionModel, actionContext: actionContext)
            }
        default:
            break
        }

        setupDiscountTag()
    }

    func prepareForReuse() {
        if let videoView = mediaContent?.videoController?.videoView {
            videoView.isHidden = true
            videoView.prepareForReuse()
        }

        cleanupBusinessSubviews()
    }

    func cleanupBusinessSubviews() {
        discountTag.removeFromSuperview()
        tapToTryAnimationView?.stop()
        tapToTryAnimationView?.removeFromSuperview()
        tapToTryStaticView.removeFromSuperview()
    }

    private func setupTapToTry(with mediaModel: NovaAdPlayableMediaModel) {
        switch mediaModel.tapToTryFormat {
        case .default:
            if let tapToTryAnimationView {
                addSubview(tapToTryAnimationView)
                tapToTryAnimationView.snp.remakeConstraints { make in
                    make.center.equalToSuperview()
                    make.size.equalTo(72.0)
                }
                tapToTryAnimationView.play()
            }
        case .gamepadWithText:
            addSubview(tapToTryStaticView)
            let bottomOffset: CGFloat = {
                let defaultOffset: CGFloat = 16
                if let safeAreaBottom = mediaContent?.elementLayout?.safeAreaInsets.bottom, safeAreaBottom > 0 {
                    return -(safeAreaBottom + defaultOffset)
                }
                return -defaultOffset
            }()
            tapToTryStaticView.snp.remakeConstraints { make in
                make.centerX.equalToSuperview()
                make.bottom.equalToSuperview().offset(bottomOffset)
            }
        }
    }

    private func setupDiscountTag() {
        if let discountTagInfo = mediaContent?.discountTagInfo {
            addSubview(discountTag)
            discountTag.config(with: discountTagInfo.style)
            discountTag.setupNormalLayout(on: self, with: discountTagInfo)
        }
    }
}
