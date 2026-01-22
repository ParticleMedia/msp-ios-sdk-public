//
//  NovaNativeAdVideoWholeScreenSubviewHandler.swift
//  Pods
//
//  Created by Shanyu Li on 2025/2/7.
//

import CoreMedia
@_implementationOnly import SnapKit
import UIKit

// MARK: - NovaNativeAdVideoPlayButtonOnCenterSubviewHandler

final class NovaNativeAdVideoPlayButtonOnCenterSubviewHandler: NSObject {
    // MARK: Lifecycle

    init(
        delegate: (any NovaAdVideoSubviewBehaviorDelegate)? = nil,
        progressBarStyle: NovaAdVideoView.Style.ProgressBarStyle? = nil,
        popupCTAStyle: NovaAdVideoView.Style.PopupCTAStyle? = nil
    ) {
        self.delegate = delegate
        self.progressBarStyle = progressBarStyle
        self.popupCTAStyle = popupCTAStyle
    }

    // MARK: Private

    private lazy var progressView: NovaVideoProgressView = .init()
    private lazy var ctaPopoverView: NovaAdPopOverView = {
        let popoverView = NovaAdPopOverView()
        popoverView.adClickArea = .cta_popover
        return popoverView
    }()

    private weak var delegate: (any NovaAdVideoSubviewBehaviorDelegate)?
    private let progressBarStyle: NovaAdVideoView.Style.ProgressBarStyle?
    private let popupCTAStyle: NovaAdVideoView.Style.PopupCTAStyle?

    private lazy var coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var playImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = .Nova.playFilled?.withTintColor(NovaColorPalettes.White)
        imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapPlayButton(_:))))
        return imageView
    }()

    private lazy var subviews: [UIView] = [coverImageView, playImageView, progressView]
}

private extension NovaNativeAdVideoPlayButtonOnCenterSubviewHandler {
    @objc func didTapPlayButton(_ gesture: UITapGestureRecognizer) {
        delegate?.didTapPlayButton(gesture)
    }

    @objc func didTapPopoverView(_ gesture: UITapGestureRecognizer) {
        delegate?.didTapAd(on: ctaPopoverView)
    }
}

extension NovaNativeAdVideoPlayButtonOnCenterSubviewHandler: NovaNativeAdVideoSubviewHandler {
    func setup(on view: UIView) {
        view.addSubviews(subviews)
        coverImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        playImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(50)
        }

        switch progressBarStyle {
        case .hide, .none:
            progressView.isHidden = true
        case .show(let bottomMargin):
            progressView.isHidden = false
            progressView.snp.makeConstraints { make in
                make.horizontalEdges.equalToSuperview()
                make.height.equalTo(1.0)
                make.bottom.equalToSuperview().inset(bottomMargin)
            }
        }
    }

    func config(with videoModel: NovaAdVideoMediaModel) {
        if let callToAction = videoModel.callToAction,
            case .show = popupCTAStyle
        {
            ctaPopoverView.config(
                with: NovaAdPopOverViewModel(
                    callToAction: callToAction,
                    advertiser: videoModel.advertiser,
                    iconURL: videoModel.iconURL,
                    styleVariant: videoModel.popupCTAStyleVariant
                )
            )
            ctaPopoverView.addGestureRecognizer(
                UITapGestureRecognizer(target: self, action: #selector(didTapPopoverView(_:)))
            )
        }
    }

    @MainActor
    func sync(with state: NovaAdVideoState) {
        switch state.playState {
        case .showCover(_, let coverURL):
            coverImageView.kf.setImage(with: coverURL)
            coverImageView.isHidden = false
            playImageView.isHidden = false
            if case .show = popupCTAStyle {
                ctaPopoverView.changeState(to: .hide)
            }
        case .loading:
            coverImageView.isHidden = true
            playImageView.isHidden = true
            if case .show = popupCTAStyle {
                ctaPopoverView.changeState(to: .hide)
            }
        case .playing(let currentTime, let videoLength):
            let currentTimeInterval = CMTimeGetSeconds(currentTime)
            coverImageView.isHidden = true
            playImageView.isHidden = true
            progressView.updateProgress(Float(currentTimeInterval / videoLength))
            if case .show = popupCTAStyle {
                ctaPopoverView.changeState(to: .hide)
            }
        case .paused(let currentTime, let videoLength, _):
            let currentTimeInterval = CMTimeGetSeconds(currentTime)
            coverImageView.isHidden = true
            playImageView.isHidden = false
            progressView.updateProgress(Float(currentTimeInterval / videoLength))
        case .endPlaying(let shouldShowPlayButton):
            coverImageView.isHidden = true
            playImageView.isHidden = !shouldShowPlayButton
            if case .show = popupCTAStyle {
                ctaPopoverView.changeState(to: .hide)
            }
        }
    }

    func toggleAllSubViewVisibility(completion: ((_ currentHideStatus: Bool) -> Void)?) {}

    func removeViewsFromSuperview() {
        subviews.forEach { $0.removeFromSuperview() }
    }

    func tapVideo(on view: UIView, at location: CGPoint, isPlaying: Bool) {
        if case .show(let safeAreaInsets, let exclusionRects) = popupCTAStyle {
            if !isPlaying {
                ctaPopoverView
                    .changeState(
                        to:
                            .pop(
                                sourceView: view,
                                sourcePoint: location,
                                extraLayoutConfig: .init(
                                    safeAreaInsets: safeAreaInsets,
                                    exclusionRects: exclusionRects
                                )
                            )
                    )
            }
        }
    }
}
