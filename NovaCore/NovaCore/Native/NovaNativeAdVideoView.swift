//
//  NovaNativeAdVideoView.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 6/18/24.
//

import Foundation
import UIKit
//@_implementationOnly import NBDesignSystem


public final class NovaNativeAdVideoView: UIView {
    
    public var didTapCloseButtonCallback: (() -> Void)?;
    
    private let inLandingPage: Bool
    private var inLandingViewsHideBlock: DispatchCancelableBlock?
    
    public var inInterstitial: Bool = false

    private let coverImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var centralPlayButton: UIButton = {
        let view = UIButton()
        view.translatesAutoresizingMaskIntoConstraints = false
        let image = UIImage.Nova.playFilledNew
        view.setImage(image, for: .normal)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapCentralPlayButton)))
        return view
    }()

    private lazy var panel: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = NovaColorPalettes.Black.nb_opacity5()
        view.layer.cornerRadius = 4
        return view
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage.Nova.crossFilled?.withTintColor(NovaColorPalettes.White), for: .normal)
        button.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapCloseButton)))
        return button
    }()

    private lazy var playButton: UIButton = {
        let view = UIButton()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.imageEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapPlayButton)))
        return view
    }()

    private lazy var muteButton: UIButton = {
        let view = UIButton()
        view.translatesAutoresizingMaskIntoConstraints = false
        if !inLandingPage {
            view.imageEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        }
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTabMuteButton)))
        return view
    }()

    private lazy var countText: UILabel = {
        let view = UILabel()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.font = .Nova.caption1
        view.textColor = NovaColorPalettes.White
        view.numberOfLines = 1
        view.backgroundColor = NovaColorPalettes.Black.nb_opacity5()
        view.layer.cornerRadius = 4
        view.textAlignment = .center
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


    private lazy var playImage: UIImage? = {
        if inLandingPage {
            UIImage.Nova.playFilled?.withTintColor(NovaColorPalettes.White)
        } else {
            UIImage.Nova.playLine?.withTintColor(NovaColorPalettes.White)
        }
    }()

    private lazy var pauseImage: UIImage? = {
        if inLandingPage {
            UIImage.Nova.pauseFilled?.withTintColor(NovaColorPalettes.White)
        } else {
            .Nova.pauseLine?.withTintColor(NovaColorPalettes.White)
        }
    }()

    private let volumnOnImage = UIImage.Nova.volumeOnLine?.withTintColor(NovaColorPalettes.White)

    private let volumnOffImage = UIImage.Nova.volumeOffLine?.withTintColor(NovaColorPalettes.White)

    public var videoPlayer: NovaVideoPlayer?

    private var videoInfo: NovaNativeAdVideoInfo?
    private var encryptedAdToken: String?

    private var playState: NovaNativeAdVideoState.PlayState? {
        willSet {
            if let newValue, newValue != playState {
                videoInfo?.state = NovaNativeAdVideoState(playState: newValue,
                                                         isMute: videoPlayer?.isPlayerMuted() == true)
            }
        }
    }
    private var showCoverKey: Double?

    private var configTime: Double? = nil
    private var startTime: Double? = nil
    private var lastResumeTime: Double? = nil
    private var lastPauseTime: Double? = nil

    private var isOnScreen: Bool = false
    public var userPausedAd: Bool = false // True: user tapped pause button on the ad, thus should not autolay the video even if it's on screen

    private var videoTapRecognizer: UITapGestureRecognizer?

    private weak var iabReporter: IABMetricReporter?
    
    public var novaNativeAdVideoDelegate: NovaNativeAdVideoDelegate?
    
    // pop over button, default is nil
    public var popOverCtaController: NovaAdPopOverCtaController?
    
    private var isVideoStartLogged = false

    public init(inLandingPage: Bool = false) {
        self.inLandingPage = inLandingPage
        super.init(frame: CGRectZero)
        if inLandingPage {
            addSubviews([closeButton, playButton, muteButton, videoProgressText, progressView, videoLengthText])
            
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            playButton.translatesAutoresizingMaskIntoConstraints = false
            muteButton.translatesAutoresizingMaskIntoConstraints = false
            videoProgressText.translatesAutoresizingMaskIntoConstraints = false
            progressView.translatesAutoresizingMaskIntoConstraints = false
            videoLengthText.translatesAutoresizingMaskIntoConstraints = false

            // closeButton constraints
            NSLayoutConstraint.activate([
                closeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 12),
                closeButton.widthAnchor.constraint(equalToConstant: 24),
                closeButton.heightAnchor.constraint(equalToConstant: 24)
            ])

            // playButton constraints
            NSLayoutConstraint.activate([
                playButton.heightAnchor.constraint(equalToConstant: 50),
                playButton.widthAnchor.constraint(equalToConstant: 50),
                playButton.centerXAnchor.constraint(equalTo: centerXAnchor),
                playButton.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])

            // muteButton constraints
            NSLayoutConstraint.activate([
                muteButton.heightAnchor.constraint(equalToConstant: 20),
                muteButton.widthAnchor.constraint(equalToConstant: 20),
                muteButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                muteButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
            ])

            // videoProgressText constraints
            NSLayoutConstraint.activate([
                videoProgressText.leadingAnchor.constraint(equalTo: muteButton.trailingAnchor, constant: 16),
                videoProgressText.centerYAnchor.constraint(equalTo: muteButton.centerYAnchor)
            ])

            // progressView constraints
            NSLayoutConstraint.activate([
                progressView.leadingAnchor.constraint(equalTo: videoProgressText.trailingAnchor, constant: 12),
                progressView.centerYAnchor.constraint(equalTo: muteButton.centerYAnchor)
            ])

            // videoLengthText constraints
            NSLayoutConstraint.activate([
                videoLengthText.leadingAnchor.constraint(equalTo: progressView.trailingAnchor, constant: 12),
                videoLengthText.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -52),
                videoLengthText.centerYAnchor.constraint(equalTo: muteButton.centerYAnchor)
            ])
        } else {
            panel.addSubviews(playButton, muteButton)
            addSubviews(coverImage, centralPlayButton, panel, countText)
            NSLayoutConstraint.activate([
                coverImage.topAnchor.constraint(equalTo: topAnchor),
                coverImage.leadingAnchor.constraint(equalTo: leadingAnchor),
                coverImage.bottomAnchor.constraint(equalTo: bottomAnchor),
                coverImage.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
            NSLayoutConstraint.activate([
                centralPlayButton.widthAnchor.constraint(equalToConstant: 50),
                centralPlayButton.heightAnchor.constraint(equalToConstant: 50),
                centralPlayButton.centerXAnchor.constraint(equalTo: centerXAnchor),
                centralPlayButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
            NSLayoutConstraint.activate([
                panel.widthAnchor.constraint(equalToConstant: 64),
                panel.heightAnchor.constraint(equalToConstant: 28),
                panel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
                panel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            ])
            NSLayoutConstraint.activate([
                playButton.widthAnchor.constraint(equalToConstant: 32),
                playButton.heightAnchor.constraint(equalToConstant: 28),
                playButton.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
                playButton.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            ])
            NSLayoutConstraint.activate([
                muteButton.widthAnchor.constraint(equalToConstant: 32),
                muteButton.heightAnchor.constraint(equalToConstant: 28),
                muteButton.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
                muteButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            ])
            NSLayoutConstraint.activate([
                countText.widthAnchor.constraint(equalToConstant: 40),
                countText.heightAnchor.constraint(equalToConstant: 24),
                countText.topAnchor.constraint(equalTo: topAnchor, constant: 12),
                countText.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            ])
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - public function

public extension NovaNativeAdVideoView {

    func config(videoInfo: NovaNativeAdVideoInfo,
                encryptedAdToken: String,
                iabReporter: IABMetricReporter?) {
        self.videoInfo = videoInfo
        self.encryptedAdToken = encryptedAdToken
        self.iabReporter = iabReporter
        
        if !videoInfo.isVideoClickable || inLandingPage {
            // Add an empty gesture recognizer to disable click on parent media view
            videoTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapVideo(_:)))
            addGestureRecognizer(videoTapRecognizer!)
        } else {
            if !videoInfo.isAuto && !videoInfo.didStart {
                videoTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapCentralPlayButton))
                addGestureRecognizer(videoTapRecognizer!)
            }
        }
        var hasCover = false
        if let coverUrlStr = videoInfo.coverUrlStr, let coverUrl = URL(string: coverUrlStr) {
            NovaUIUtils.setImage(from: coverUrl, to: coverImage) {
                
            }
            hasCover = true
        }
        
        setupPlayer(videoInfo: videoInfo, encryptedAdToken: encryptedAdToken)
        setSubviewsOnVideo(videoInfo: videoInfo, inLandingPage: inLandingPage)
        syncPlayState(from: videoInfo, hasCover: hasCover)
    }

    func prepareForReuse() {
        videoPlayer?.stop(endKind: .none)
        playState = nil
        videoInfo = nil
        if let videoTapRecognizer = videoTapRecognizer {
            removeGestureRecognizer(videoTapRecognizer)
            self.videoTapRecognizer = nil
        }
        videoPlayer?.getPlayerView().removeFromSuperview()
    }
    
    func getPlayerSuperview() -> UIView? {
        videoPlayer?.getPlayerView().superview
    }
    
    func setPlayerBackOnView(view: UIView) {
        if let playerView = videoPlayer?.getPlayerView(), playerView.superview != view {
            playerView.removeFromSuperview()
            view.insertSubview(playerView, at: 0)
            playerView.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                playerView.topAnchor.constraint(equalTo: view.topAnchor),
                playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            view.layoutIfNeeded()
        }
    }

    func handleVideoOnScreen() {
        isOnScreen = true
        setPlayerBackOnView(view: self)
        if self.videoPlayer?.isVideoPlaying() ?? false ||
            userPausedAd {
            // if user clicked the pause button, do not resume video
            return
        }
        if let videoInfo, let state = videoInfo.state {
            syncVideoPlayingState(with: state.playState)
            updateUI(with: state.playState)
        }
    }

    func handleVideoOffScreen() {
        if !isOnScreen {
            return
        }
        isOnScreen = false
        
        if let playerView = self.videoPlayer?.getPlayerView(),
           playerView.superview != self {
            return
        }

        guard let playState = playState else {
            return
        }
        switch playState {
        case .showCover(_):
            showCoverKey = nil
        case .loading(_), .playing(_):
            // NOTE(SHANYU): pause video here do not need to be sync to video info, or video won't auto play next time entering
            pauseVideo(endKind: .stopAutoPlayInFeed)
        default:
            break
        }
    }
}

// MARK: - private function

private extension NovaNativeAdVideoView {
    func updateUI(with playState: NovaNativeAdVideoState.PlayState?) {
        guard let playState else { return }
        switch playState {
        case .showCover(_):
            centralPlayButton.isHidden = false
            coverImage.isHidden = false
            panel.isHidden = true
        case .loading(let hideCover):
            centralPlayButton.isHidden = hideCover
            coverImage.isHidden = hideCover
            panel.isHidden = true
        case .playing(_):
            updatePlayButton(true)
            centralPlayButton.isHidden = true
            coverImage.isHidden = true
            updatePlayButton(true)
            if shouldShowVideoController() {
                panel.isHidden = false
            } else {
                panel.isHidden = true
            }
        case .paused(_):
            updatePlayButton(false)
            coverImage.isHidden = true
            if shouldShowVideoController() {
                panel.isHidden = false
            } else {
                panel.isHidden = true
                centralPlayButton.isHidden = false
            }
        case .complete:
            centralPlayButton.isHidden = false
            coverImage.isHidden = true
            panel.isHidden = true
        }
    }
    
    func syncVideoPlayingState(with playState: NovaNativeAdVideoState.PlayState?) {
        guard let playState else { return }
        switch playState {
        case .showCover(let autoPlay):
            if autoPlay {
                startCover()
            }
        case .loading(_):
            startVideo()
        case .playing(let currentTime):
            if !currentTime.isIndefinite {
                videoPlayer?.seek(to: currentTime, completionHandler: nil)
            }
            self.resumeVideo()
        case .paused(let currentTime):
            if !currentTime.isIndefinite {
                videoPlayer?.seek(to: currentTime, completionHandler: nil)
            }
            self.pauseVideo(endKind: .none)
        case .complete:
            break
        }
    }

    func startCover() {
        let key = CACurrentMediaTime()
        showCoverKey = key
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            if key != self?.showCoverKey {
                return
            }
            if let videoPlayer = self?.videoPlayer {
                self?.startVideo()
            }
        }
    }

    func startVideo() {
        guard let videoPlayer = videoPlayer else {
            return
        }

        startTime = CACurrentMediaTime()
        lastResumeTime = startTime
        let playState: NovaNativeAdVideoState.PlayState = .playing(currentTime: videoPlayer.currentTime())
        self.playState = playState
        self.updateUI(with: playState)
        videoPlayer.play()
    }

    func resumeVideo() {
        guard let videoPlayer = videoPlayer else {
            return
        }

        videoPlayer.delegate = self
        videoPlayer.play()
        iabReporter?.logVideoResume()
        let resumeTime = CACurrentMediaTime()
        if let encryptedAdToken = self.encryptedAdToken,
           let lastPauseTime {
            NovaAdVideoMetricReporter.logVideoResume(encryptedAdToken: encryptedAdToken,
                                                     duration: resumeTime - lastPauseTime)
        }
        lastResumeTime = resumeTime
    }

    func pauseVideo(endKind: NovaVideoEndKind) {
        guard let videoPlayer = videoPlayer else {
            return
        }
        videoPlayer.pause(endKind: endKind)
        iabReporter?.logVideoPause()
        let pauseTime = CACurrentMediaTime()
        if let encryptedAdToken = self.encryptedAdToken,
           let lastResumeTime {
            NovaAdVideoMetricReporter.logVideoPause(encryptedAdToken: encryptedAdToken,
                                                    duration: pauseTime - lastResumeTime)
        }
        lastPauseTime = pauseTime
    }

    private func updatePlayButton(_ isPlaying: Bool) {
        playButton.setImage(isPlaying ? pauseImage : playImage, for: .normal)
    }

    private func setVideoMute(_ isMute: Bool) {
        guard let videoPlayer = videoPlayer else {
            return
        }
        videoPlayer.setPlayerMute(isMute)
        if let playState {
            videoInfo?.state = NovaNativeAdVideoState(playState: playState, isMute: isMute)
        }
        muteButton.setImage(isMute ? volumnOffImage : volumnOnImage, for: .normal)
        iabReporter?.logVideoVolumeChange(to: isMute ? 0.0 : 1.0)
    }

    private func stringOf(timeInterval: Int?) -> String {
        guard let timeInterval else {
            return "NaN:NaN"
        }
        let second = timeInterval % 60
        let minute = timeInterval / 60
        let secondStr = second < 10 ? "0\(second)" : "\(second)"
        let minuteStr = minute < 10 ? "0\(minute)" : "\(minute)"
        return "\(minuteStr):\(secondStr)"
    }
    
    private func setupPlayer(
        videoInfo: NovaNativeAdVideoInfo,
        encryptedAdToken: String
    ) {
        guard let videoUrl = URL(string: videoInfo.videoUrlStr) else {
            assertionFailure("Invalid video url: \(videoInfo.videoUrlStr)")
            return
        }
        guard let videoPlayer = NovaVideoPlayerCacheHandler
            .shared
            .getCachedVideoControllerForURL(videoUrl, cacheKey: videoInfo.cacheKey) else {
            return
        }
        self.videoPlayer = videoPlayer
        self.configTime = CACurrentMediaTime()
        NovaAdVideoMetricReporter.makeRecord(encryptedAdToken: encryptedAdToken)
        let playerView = videoPlayer.getPlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        if playerView.superview != nil {
            playerView.removeFromSuperview()
        }
        insertSubview(playerView, at: 0)
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: topAnchor),
            playerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            playerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            playerView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        let playInfo = NovaPlayInfo(url: videoUrl,
                                playLoops: videoInfo.isLoop,
                                videoDataModel: nil,
                                playStyle: .feed,
                                isMute: videoInfo.isMute,
                                disableGesture: true)
        videoPlayer.play(with: playInfo, actionHandler: nil, delegate: self)
    }
    
    private func setSubviewsOnVideo(videoInfo: NovaNativeAdVideoInfo, inLandingPage: Bool) {
        if inLandingPage {
            updateLandingSubviews(isHidden: false)
            self.inLandingViewsHideBlock = dispatchMainAsyncAfter(delay: 3.0, block: DispatchWorkItem(block: { [weak self] in
                self?.updateLandingSubviews(isHidden: true)
            }))
            guard let videoPlayer else { return }
            videoLengthText.text = stringOf(timeInterval: videoPlayer.maximumTimeDuration().toIntValue())
            switch videoInfo.state?.playState {
            case .playing(_), .paused(_):
                progressView.setProgress(Float(videoPlayer.getRealProgress().truncatingRemainder(dividingBy: 1.0)), animated: false)
                videoProgressText.text = stringOf(timeInterval: videoPlayer.currentTimeInterval().toIntValue())
            default:
                videoProgressText.text = stringOf(timeInterval: 0)
            }
        } else {
            countText.isHidden = true
        }
    }
    
    private func syncPlayState(from videoInfo: NovaNativeAdVideoInfo, hasCover: Bool) {
        if let state = videoInfo.state {
            playState = state.playState
            setVideoMute(state.isMute)
        } else {
            if hasCover {
                playState = .showCover(autoPlay: videoInfo.isAuto)
            } else {
                playState = videoInfo.isAuto ? .loading(hideCover: true) : .complete
            }
            setVideoMute(videoInfo.isMute)
        }
        updateUI(with: playState)
        syncVideoPlayingState(with: playState)
    }
    
    private func updateLandingSubviews(isHidden: Bool) {
        closeButton.isHidden = isHidden
        muteButton.isHidden = isHidden
        videoProgressText.isHidden = isHidden
        progressView.isHidden = isHidden
        videoLengthText.isHidden = isHidden
        playButton.isHidden = isHidden
    }
    
    private func shouldShowVideoController() -> Bool {
        if !(videoInfo?.isVideoClickable ?? true) {
            //do not show buttons when view is in immersive flow (video not clickable)
            return false
        }
        if (inInterstitial && (videoInfo?.isVertical ?? false)) {
            //do not show buttons when it is vertical interstitial
            return false
        }
        return true
    }
}

// MARK: - User Event

private extension NovaNativeAdVideoView {

    @objc func didTapVideo(_ gesture: UITapGestureRecognizer) {
        // Do nothing
        if inLandingPage {
            let currentHiddenStatus = muteButton.isHidden
            updateLandingSubviews(isHidden: !currentHiddenStatus)
            
            if !currentHiddenStatus {
                dispatchCancel(block: self.inLandingViewsHideBlock)
            } else {
                self.inLandingViewsHideBlock = dispatchMainAsyncAfter(delay: 3.0, block: DispatchWorkItem(block: { [weak self] in
                    self?.updateLandingSubviews(isHidden: true)
                }))
            }
        } else if !(videoInfo?.isVideoClickable ?? true) {
            let locationRect = CGRect(origin: gesture.location(in: self), size: .zero)
            if !userPausedAd {
                self.popOverCtaController?.changeState(to: .pop(source: (self, locationRect)))
            } else {
                self.popOverCtaController?.changeState(to: .hide)
            }
            self.didTapPlayButton()
        }
    }

    @objc public func didTapPlayButton() {
        guard let videoPlayer = videoPlayer else {
            return
        }
        playState = videoPlayer.isVideoPlaying() ?
            .paused(currentTime: videoPlayer.currentTime()) :
            .playing(currentTime: videoPlayer.currentTime())
        updateUI(with: playState)
        if videoPlayer.isVideoPlaying() {
            if !inLandingPage {
                userPausedAd = true
            }
            pauseVideo(endKind: .pause)
        } else {
            if !inLandingPage {
                userPausedAd = false
            }
            resumeVideo()
        }
    }

    @objc public func didTabMuteButton() {
        guard let videoPlayer = videoPlayer else {
            return
        }
        setVideoMute(!videoPlayer.isPlayerMuted())
        if let encryptedAdToken = self.encryptedAdToken {
            NovaAdVideoMetricReporter.logVideoMute(encryptedAdToken: encryptedAdToken,
                                                   isMute: videoPlayer.isPlayerMuted())
        }
    }

    @objc func didTapCentralPlayButton() {
        guard let videoPlayer = videoPlayer else {
            return
        }
        
        playState = .playing(currentTime: videoPlayer.currentTime())
        updateUI(with: playState)
        
        if !inLandingPage {
            userPausedAd = false
            self.popOverCtaController?.changeState(to: .hide)
        }
        resumeVideo()
    }
    
    @objc func didTapCloseButton() {
        if let didTapCloseButtonCallback {
            didTapCloseButtonCallback()
        }
    }

    func updateVideoInfoState(_ player: NovaPlayer) {
        guard let videoPlayer, let videoInfo else {
            return
        }
        if videoPlayer.getCurrentProgress() >= 1 && !videoInfo.isLoop {
            playState = .complete
        }
        //if videoPlayer.isVideoPlaying() {
        //    playState = .playing(currentTime: videoPlayer.currentTime())
        //}
        updateUI(with: playState)
        //syncVideoPlayingState(with: playState)
    }
    
}

// MARK: - VideoPlayerDelegate

extension NovaNativeAdVideoView: NovaVideoPlayerDelegate {
    public func playerReady(_ player: NovaPlayer) {}

    public func playerPlaybackStateDidChange(_ player: NovaPlayer) {
        guard let videoPlayer = videoPlayer else {
            return
        }
        guard let videoInfo = self.videoInfo else { return }
        if videoPlayer.isVideoPlaying() {
            if videoInfo.isVideoClickable && !inLandingPage, let videoTapRecognizer = videoTapRecognizer {
                videoInfo.didStart = true
                removeGestureRecognizer(videoTapRecognizer)
                self.videoTapRecognizer = nil
            }
        }

        updateVideoInfoState(player)
    }

    public func playerBufferTimeDidChange(_ bufferTime: Double) {
    }

    public func playerCurrentTimeDidChange(_ player: NovaPlayer) {
        guard let videoPlayer = videoPlayer else {
            return
        }
        let videoCurrent = videoPlayer.currentTimeInterval()
        let videoLength = player.maximumDuration
        if videoCurrent.isNaN || videoLength.isNaN {
            return
        }
        switch playState {
        case .playing(_):
            playState = .playing(currentTime: videoPlayer.currentTime())
        case .paused(_):
            playState = .paused(currentTime: videoPlayer.currentTime())
        default:
            break
        }
        if inLandingPage {
            videoProgressText.text = stringOf(timeInterval: Int(videoCurrent.truncatingRemainder(dividingBy: videoLength)))
            progressView.setProgress(Float(videoPlayer.getRealProgress().truncatingRemainder(dividingBy: 1.0)), animated: false)
        } else if inInterstitial {
            countText.isHidden = true
        } else if !countText.isHidden {
            countText.text = stringOf(timeInterval: Int(videoLength - videoCurrent))
            if videoCurrent > 5 {
                countText.isHidden = true
            }
        }
        guard let videoInfo = self.videoInfo else { return }
        guard let encryptedAdToken = self.encryptedAdToken else { return }
        if let startTime, let configTime, !isVideoStartLogged {
            isVideoStartLogged = true
            let time = CACurrentMediaTime()
            let duration = time - configTime
            let latency = time - startTime
            NovaAdVideoMetricReporter.logVideoStart(encryptedAdToken: encryptedAdToken,
                                                    isAuto: videoInfo.isAuto,
                                                    isMute: videoInfo.isMute,
                                                    isLoop: videoInfo.isLoop,
                                                    videoLength: videoLength,
                                                    latency: latency,
                                                    duration: duration)
            iabReporter?.logVideoStart(duration: videoCurrent, volume: videoPlayer.isPlayerMuted() ? 0.0 : 1.0)
        }
        NovaAdVideoMetricReporter.logVideoProgress(encryptedAdToken: encryptedAdToken,
                                                   percentage: videoCurrent / videoLength,
                                                   duration: videoCurrent)
        iabReporter?.logVideoProgress(percentage: videoCurrent / videoLength)
        novaNativeAdVideoDelegate?.playerCurrentTimeDidChange?(currentTime: videoPlayer.currentTimeInterval(), durationTime: videoLength)
    }

    public func playerTimePassed60sAfterPlay(_ player: NovaPlayer) {
    }

    public func player(_ player: NovaPlayer, didFailWithError error: Error?) {
        if let encryptedAdToken, let configTime {
            NovaAdVideoMetricReporter.logVideoError(encryptedAdToken: encryptedAdToken,
                                                    error: error?.localizedDescription ?? "",
                                                    duration: CACurrentMediaTime() - configTime)
        }
    }

    public func playerDidPlayToEndTime(_ player: NovaPlayer) {
        novaNativeAdVideoDelegate?.playerDidPlayToEndTime?()
    }
    
    public func playerPlaybackWillLoop(_ player: NovaPlayer) {
        
    }

    public func playerPlaybackDidLoop(_ player: NovaPlayer) {
    }
}


private extension TimeInterval {
    func toIntValue() -> Int? {
        /// NOTE: (shanyu.li) convert NaN to Int will crash
        guard self.isFinite else {
            return nil
        }
        if self > Double(Int.max) {
            return Int.max
        } else if self < Double(0) {
            return 0
        } else {
            return Int(self)
        }
    }
}
