//
//  NovaNativeAdVideoDefaultSubviewHandler.swift
//  Pods
//
//  Created by Shanyu Li on 2025/2/5.
//

@_implementationOnly import SnapKit
import CoreMedia
import UIKit

final class NovaNativeAdVideoPlayButtonOnLeftBottomSubviewHandler: NSObject {
    private weak var delegate: (any NovaAdVideoSubviewBehaviorDelegate)?

    private lazy var coverImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var startButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = .Nova.playFilled?.withTintColor(NovaColorPalettes.White)
        configuration.imagePadding = 12
        configuration.baseBackgroundColor = NovaColorPalettes.Black.withAlphaComponent(0.3)
        let view = UIButton(configuration: configuration)
        view.layer.cornerRadius = 24
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapStartButton)))
        return view
    }()

    private lazy var panel: UIView = {
        let view = UIView()
        view.backgroundColor = NovaColorPalettes.Black.withAlphaComponent(0.3)
        view.layer.cornerRadius = 4
        return view
    }()

    private lazy var playButton: UIButton = {
        let view = UIButton()
        view.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapPlayButton(_:))))
        return view
    }()

    private lazy var volumeButton: UIButton = {
        let view = UIButton()
        view.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapMuteButton)))
        return view
    }()

    private lazy var countText: UILabel = {
        let view = UILabel()
        view.font = .Nova.caption1
        view.textColor = NovaColorPalettes.White
        view.numberOfLines = 1
        view.backgroundColor = NovaColorPalettes.Black.withAlphaComponent(0.3)
        view.layer.cornerRadius = 4
        view.textAlignment = .center
        return view
    }()

    private lazy var subviews: [UIView] = {
        [coverImage, startButton, panel, countText]
    }()

    private let playImage = UIImage.Nova.playLine?.withTintColor(NovaColorPalettes.White).imageByResize(
        to: CGSize(width: 16, height: 16)
    )

    private let pauseImage = UIImage.Nova.pauseLine?.withTintColor(NovaColorPalettes.White).imageByResize(
        to: CGSize(width: 16, height: 16)
    )

    private let volumeOnImage = UIImage.Nova.volumeOnLine?.withTintColor(NovaColorPalettes.White).imageByResize(
        to: CGSize(width: 16, height: 16)
    )

    private let volumeOffImage = UIImage.Nova.volumeOffLine?.withTintColor(NovaColorPalettes.White).imageByResize(
        to: CGSize(width: 16, height: 16)
    )

    init(delegate: (any NovaAdVideoSubviewBehaviorDelegate)? = nil) {
        self.delegate = delegate
    }
}

private extension NovaNativeAdVideoPlayButtonOnLeftBottomSubviewHandler {
    @objc func didTapStartButton() {
        delegate?.didTapStartButton()
    }

    @objc func didTapPlayButton(_ gesture: UITapGestureRecognizer) {
        delegate?.didTapPlayButton(gesture)
    }

    @objc func didTapMuteButton() {
        delegate?.didTapMuteButton()
    }
}

extension NovaNativeAdVideoPlayButtonOnLeftBottomSubviewHandler: NovaNativeAdVideoSubviewHandler {
    func setup(on view: UIView) {
        panel.addSubviews(playButton, volumeButton)
        view.addSubviews(subviews)
        coverImage.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        startButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(48)
        }
        panel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.bottom.equalToSuperview().offset(-12)
            make.height.equalTo(28)
            make.width.equalTo(64)
        }
        playButton.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.width.equalTo(32)
            make.height.equalTo(28)
        }
        volumeButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.width.equalTo(32)
            make.height.equalTo(28)
        }
        countText.snp.makeConstraints { make in
            make.width.equalTo(40)
            make.height.equalTo(24)
            make.top.trailing.equalToSuperview().inset(12)
        }
    }

    func sync(with state: NovaAdVideoState) {
        volumeButton.setImage(state.isMute ? volumeOffImage: volumeOnImage, for: .normal)
        switch state.playState {
        case .showCover(_, coverURL: let coverURL):
            coverImage.kf.setImage(with: coverURL)
            coverImage.isHidden = false
            startButton.isHidden = false
            panel.isHidden = true
            countText.isHidden = true
        case .loading:
            coverImage.isHidden = true
            startButton.isHidden = true
            panel.isHidden = true
            countText.isHidden = true
        case .playing(let currentTime, let videoLength):
            let currentTimeInterval = CMTimeGetSeconds(currentTime)
            coverImage.isHidden = true
            startButton.isHidden = true
            panel.isHidden = false
            playButton.setImage(pauseImage, for: .normal)
            if let text = (videoLength - currentTimeInterval).toMMSSString() {
                countText.text = text
                countText.isHidden = currentTimeInterval > 5
            } else {
                countText.isHidden = true
            }
        case .paused(let currentTime, let videoLength, _):
            let currentTimeInterval = CMTimeGetSeconds(currentTime)
            coverImage.isHidden = true
            startButton.isHidden = true
            panel.isHidden = false
            playButton.setImage(playImage, for: .normal)
            if let text = (videoLength - currentTimeInterval).toMMSSString() {
                countText.text = text
                countText.isHidden = currentTimeInterval > 5
            } else {
                countText.isHidden = true
            }
        case .endPlaying(shouldShowPlayButton: let shouldShowPlayButton):
            coverImage.isHidden = true
            startButton.isHidden = !shouldShowPlayButton
            panel.isHidden = true
            countText.isHidden = true
        }
    }

    func toggleAllSubViewVisibility(completion: ((_ currentHideStatus: Bool) -> Void)?) {}

    func removeViewsFromSuperview() {
        subviews.forEach { $0.removeFromSuperview() }
    }
}

