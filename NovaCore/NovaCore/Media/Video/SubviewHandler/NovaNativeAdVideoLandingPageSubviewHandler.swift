//
//  NBNovaAdMedia
//
//  Created by Shanyu Li on 2025/2/5.
//

@_implementationOnly import SnapKit
import CoreMedia
import UIKit

final class NovaNativeAdVideoLandingPageSubviewHandler: NSObject {
    private enum Constants {
        static let closeButtonTopPadding = 12.0
        static let closeButtonLeadingPadding = 16.0
        static let closeButtonInset = 6.0
        static let closeButtonImageSize = 24.0
    }
    private weak var delegate: (any NovaAdVideoSubviewBehaviorDelegate)?

    private lazy var closeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = .Nova.crossFilled?
            .withTintColor(NovaColorPalettes.White)
            .imageByResize(to: CGSize(width: Constants.closeButtonImageSize, height: Constants.closeButtonImageSize))
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: Constants.closeButtonInset,
            leading: Constants.closeButtonInset,
            bottom: Constants.closeButtonInset,
            trailing: Constants.closeButtonInset
        )
        let button = UIButton(configuration: configuration)
        button.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapCloseButton)))
        return button
    }()

    private lazy var playButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        let view = UIButton(configuration: configuration)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapPlayButton(_:))))
        return view
    }()

    private lazy var volumeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        let view = UIButton(configuration: configuration)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapMuteButton)))
        return view
    }()

    private lazy var videoProgressText: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10)
        label.textColor = NovaColorPalettes.White
        label.numberOfLines = 1
        label.backgroundColor = .clear
        label.textAlignment = .center
        return label
    }()

    private lazy var videoLengthText: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10)
        label.textColor = NovaColorPalettes.White
        label.numberOfLines = 1
        label.backgroundColor = .clear
        label.textAlignment = .center
        return label
    }()

    private lazy var progressView: UIProgressView = {
        let progress = UIProgressView()
        progress.progressTintColor = NovaColorPalettes.Blue.tint500
        progress.trackTintColor = NovaColorPalettes.White
        return progress
    }()

    private lazy var subviews: [UIView] = [
        closeButton,
        playButton,
        volumeButton,
        videoProgressText,
        progressView,
        videoLengthText
    ]

    private let playImage = UIImage.Nova.playFilled?.withTintColor(NovaColorPalettes.White).imageByResize(
        to: CGSize(width: 40, height: 40)
    )

    private let pauseImage = UIImage.Nova.pauseFilled?.withTintColor(NovaColorPalettes.White).imageByResize(
        to: CGSize(width: 40, height: 40)
    )

    private let volumeOnImage = UIImage.Nova.volumeOnLine?.withTintColor(NovaColorPalettes.White).imageByResize(
        to: CGSize(width: 20, height: 20)
    )

    private let volumeOffImage = UIImage.Nova.volumeOffLine?.withTintColor(NovaColorPalettes.White).imageByResize(
        to: CGSize(width: 20, height: 20)
    )

    init(delegate: (any NovaAdVideoSubviewBehaviorDelegate)? = nil) {
        self.delegate = delegate
    }
}

private extension NovaNativeAdVideoLandingPageSubviewHandler {
    @objc func didTapCloseButton() {
        delegate?.didTapCloseButton()
    }

    @objc func didTapPlayButton(_ gesture: UITapGestureRecognizer) {
        delegate?.didTapPlayButton(gesture)
    }

    @objc func didTapMuteButton() {
        delegate?.didTapMuteButton()
    }
}

extension NovaNativeAdVideoLandingPageSubviewHandler: NovaNativeAdVideoSubviewHandler {
    func setup(on view: UIView) {
        view.addSubviews(subviews)
        closeButton.snp.makeConstraints { make in
            make.leading.equalTo(Constants.closeButtonLeadingPadding - Constants.closeButtonInset)
            make.top.equalTo(Constants.closeButtonTopPadding - Constants.closeButtonInset)
            make.height.width.equalTo(Constants.closeButtonImageSize + 2 * Constants.closeButtonInset)
        }
        playButton.snp.makeConstraints { make in
            make.height.width.equalTo(50)
            make.center.equalToSuperview()
        }
        volumeButton.snp.makeConstraints { make in
            make.height.equalTo(32)
            make.width.equalTo(36)
            make.leading.equalTo(16)
            make.bottom.equalTo(-8)
        }
        videoProgressText.snp.makeConstraints { make in
            make.leading.equalTo(self.volumeButton.snp.trailing).offset(16)
            make.centerY.equalTo(self.volumeButton)
        }
        progressView.snp.makeConstraints { make in
            make.leading.equalTo(self.videoProgressText.snp.trailing).offset(12)
            make.centerY.equalTo(self.volumeButton)
        }
        videoLengthText.snp.makeConstraints { make in
            make.leading.equalTo(self.progressView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-52)
            make.centerY.equalTo(self.volumeButton)
        }
        toggleAllSubViewVisibility(completion: nil)
    }

    func sync(with state: NovaAdVideoState) {
        volumeButton.setImage(state.isMute ? volumeOffImage: volumeOnImage, for: .normal)
        switch state.playState {
        case .showCover, .endPlaying, .loading:
            closeButton.isHidden = false
            playButton.isHidden = false
            volumeButton.isHidden = true
            videoProgressText.isHidden = true
            progressView.isHidden = true
            videoLengthText.isHidden = true
        case .playing(let currentTime, let videoLength):
            let currentTimeInterval = CMTimeGetSeconds(currentTime)
            playButton.setImage(pauseImage, for: .normal)
            if let text = videoLength.toMMSSString() {
                videoLengthText.text = text
                videoLengthText.isHidden = false
            } else {
                videoLengthText.isHidden = true
            }
            if let text = currentTimeInterval.toMMSSString() {
                videoProgressText.text = text
                videoProgressText.isHidden = false
            } else {
                videoProgressText.isHidden = true
            }

            progressView
                .setProgress(Float(currentTimeInterval / videoLength), animated: false)
        case .paused(let currentTime, let videoLength, _):
            let currentTimeInterval = CMTimeGetSeconds(currentTime)
            playButton.setImage(playImage, for: .normal)
            playButton.isHidden = false
            if let text = videoLength.toMMSSString() {
                videoLengthText.text = text
                videoLengthText.isHidden = false
            } else {
                videoLengthText.isHidden = true
            }
            if let text = currentTimeInterval.toMMSSString() {
                videoProgressText.text = text
                videoProgressText.isHidden = false
            } else {
                videoProgressText.isHidden = true
            }

            progressView
                .setProgress(Float(currentTimeInterval / videoLength), animated: false)
        }
    }

    func toggleAllSubViewVisibility(completion: ((_ currentHideStatus: Bool) -> Void)?) {
        let currentHideStatus = closeButton.isHidden
        closeButton.isHidden = !currentHideStatus
        playButton.isHidden = !currentHideStatus
        volumeButton.isHidden = !currentHideStatus
        videoProgressText.isHidden = !currentHideStatus
        progressView.isHidden = !currentHideStatus
        videoLengthText.isHidden = !currentHideStatus
        completion?(!currentHideStatus)
    }

    func removeViewsFromSuperview() {
        subviews.forEach { $0.removeFromSuperview() }
    }
}
