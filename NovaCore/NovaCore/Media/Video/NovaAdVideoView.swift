//
//  NovaAdVideoView.swift
//  NBNovaAds
//
//  Created by Felix Dai on 2022/9/20.
//
import CoreMedia
import UIKit

// MARK: - NovaNativeAdVideoViewExtraConfig

struct NovaNativeAdVideoViewExtraConfig: Codable {
    init() {}
}

// MARK: - NovaAdVideoViewDelegate

public protocol NovaAdVideoViewDelegate: AnyObject {
    // MARK: Optional Methods

    func videoViewDidTapCloseButton()

    func videoViewCurrentTimeDidChange(loopCount: Int, currentTime: TimeInterval, videoLength: TimeInterval)

    func videoViewDidPlayToEndTime()

    func videoViewDidChangeToPlay()
}

public extension NovaAdVideoViewDelegate {
    func videoViewDidTapCloseButton() {}

    func videoViewCurrentTimeDidChange(loopCount: Int, currentTime: TimeInterval, videoLength: TimeInterval) {}

    func videoViewDidPlayToEndTime() {}

    func videoViewDidChangeToPlay() {}
}

public final class NovaAdVideoView: UIView {
    // MARK: Lifecycle

    init(with style: Style = .playButtonOnLeftBottom) {
        self.style = style
        super.init(frame: CGRectZero)
        let playerView = videoPlayer.getPlayerView()
        insertSubview(playerView, at: 0)
        playerView.snp.makeConstraints { make in
            make.directionalEdges.equalToSuperview()
        }
        subviewHandler = NovaNativeAdVideoSubviewHandlerCreator.create(with: style, delegate: self)
        subviewHandler?.setup(on: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Public

    public enum Style: Equatable {
        case playButtonOnLeftBottom
        case playButtonOnCenter(progressBarStyle: ProgressBarStyle)
        // only use for landing page
        case landingPage
        // no subviews, only player
        case clear

        // MARK: Public

        public enum ProgressBarStyle: Equatable {
            case hide
            case show(bottomMargin: CGFloat)

            // MARK: Public

            public static func == (lhs: ProgressBarStyle, rhs: ProgressBarStyle) -> Bool {
                switch (lhs, rhs) {
                case (.hide, .hide):
                    return true
                case (.show(let lhsBottomMargin), .show(let rhsBottomMargin)):
                    return lhsBottomMargin == rhsBottomMargin
                default:
                    return false
                }
            }
        }

        public static func == (lhs: NovaAdVideoView.Style, rhs: NovaAdVideoView.Style) -> Bool {
            switch (lhs, rhs) {
            case (.clear, .clear):
                return true
            case (.playButtonOnLeftBottom, .playButtonOnLeftBottom):
                return true
            case (.playButtonOnCenter(let lhsProgressBarStyle), .playButtonOnCenter(let rhsProgressBarStyle)):
                return lhsProgressBarStyle == rhsProgressBarStyle
            case (.landingPage, .landingPage):
                return true
            default:
                return false
            }
        }
    }

    // MARK: Internal

    weak var delegate: (any NovaAdVideoViewDelegate)?

    var style: Style {
        willSet {
            if newValue != style {
                resetStyle(newValue)
            }
        }
    }

    var muted: Bool = true {
        didSet {
            videoPlayer.setPlayerMute(muted)
            if oldValue != muted, let state {
                self.state = .init(playState: state.playState, isMute: muted)
            }
        }
    }

    // MARK: Private

    private var subviewHandler: (any NovaNativeAdVideoSubviewHandler)? = nil
    private var delayedHideViewBlock: DispatchCancelableBlock?

    private var videoPlayer: NovaVideoPlayer = .init()
    private var videoPlayerConfigTask: Task<Void, Never>?
    // to make sure if you use `stop` after `play`, the final state of video is `end`
    private var playVersion: Int = 0

    private var willAutoPlayingAfterShowCover: Bool = false

    private var mediaModel: NovaAdVideoMediaModel?
    private var actionContext: NovaAdMediaActionContext?

    private var showCoverKey: Double?
    private var videoStartPlayingAfterFinishLoading = false

    private var configTime: Double? = nil
    private var startTime: Double? = nil
    private var lastResumeTime: Double? = nil
    private var lastPauseTime: Double? = nil

    private var actionHelper: NovaActionHelper<NovaActionState.Init>?

    private weak var iabReporter: IABMetricReporter?

    private var isPausedByUser = false

    // MARK: - Subviews

    private lazy var endCard: NovaAdEndCard = .init(delegate: self)

    private var state: NovaAdVideoState? {
        didSet {
            if let state {
                if case .showCover = state.playState {
                } else {
                    willAutoPlayingAfterShowCover = false
                }
                mediaModel?.videoInfo.state = state
                subviewHandler?.sync(with: state)
            }
        }
    }

    private var loopCount: Int = 0 {
        didSet {
            if oldValue != loopCount {
                mediaModel?.videoInfo.state?.loopCount = loopCount
            }
        }
    }
}

// MARK: - function

extension NovaAdVideoView {
    func config(
        with model: NovaAdVideoMediaModel,
        actionContext: NovaAdMediaActionContext?,
        iabReporter: IABMetricReporter?
    ) {
        self.mediaModel = model
        self.actionContext = actionContext
        self.iabReporter = iabReporter
        self.loopCount = mediaModel?.videoInfo.state?.loopCount ?? 0

        videoPlayerConfigTask = Task(priority: .high) {
            await setupPlayer(videoInfo: model.videoInfo)
        }

        state = {
            if let state = model.videoInfo.state {
                return state
            }
            if let coverUrlStr = model.videoInfo.coverUrlStr, let url = URL(string: coverUrlStr) {
                return .init(playState: .showCover(autoPlay: model.videoInfo.isAuto, coverURL: url), isMute: model.videoInfo.isMute)
            } else {
                return .init(
                    playState: model.videoInfo.isAuto ? .loading : .endPlaying(shouldShowPlayButton: true),
                    isMute: model.videoInfo.isMute
                )
            }
        }()
        muted = model.videoInfo.isMute
        setupActionHelper()
        setupTapGesture()
        configEndCard()
        subviewHandler?.config(with: model)
    }

    func prepareForReuse() {
        videoPlayer.stop(endKind: .none)
        state = nil
        mediaModel = nil
        videoStartPlayingAfterFinishLoading = false
    }

    enum PlayStrategy {
        case fromBeginning
        case continueFromLast
    }

    func play(with playStrategy: PlayStrategy) {
        guard !isPausedByUser else {
            return
        }
        guard !videoPlayer.isVideoPlaying() else {
            return
        }

        playVersion += 1
        let playVersionAtStart = playVersion
        Task(priority: .userInitiated) {
            await videoPlayerConfigTask?.value
            guard playVersionAtStart == playVersion else {
                return
            }

            switch playStrategy {
            case .fromBeginning:
                startPlayingFromBeginning()
            case .continueFromLast:
                if let state {
                    syncVideoPlayerState(state)
                }
            }
        }
    }

    func pause() {
        guard let playState = mediaModel?.videoInfo.state?.playState else {
            assertionFailure("lack state info")
            return
        }

        playVersion += 1
        switch playState {
        case .showCover:
            showCoverKey = nil
        case .loading, .playing:
            pauseVideo(endKind: .none)
        default:
            break
        }
    }

    // TODO: lsy, check 一下实现对不对
    func stop() {
        playVersion += 1
        videoPlayer.stop(endKind: .none)
        lastPauseTime = CACurrentMediaTime()
    }

    func toggleAllSubviewVisibilityAndRecover(after time: TimeInterval) {
        subviewHandler?.toggleAllSubViewVisibility(completion: nil)
        delayedHideViewBlock = dispatchMainAsyncAfter(
            delay: time,
            block: DispatchWorkItem(block: { [weak self] in
                self?.subviewHandler?.toggleAllSubViewVisibility(completion: nil)
            }
            )
        )
    }

    func apply(extraConfig: NovaNativeAdVideoViewExtraConfig) {}

    // MARK: - Compatibility methods for NovaNativeAdMediaView

    func handleVideoOnScreen() {
        // Resume video playback when on screen
        if let state = state, case .endPlaying = state.playState {
            // Video was paused, resume it
            play(with: .continueFromLast)
        }
    }

    func handleVideoOffScreen() {
        // Pause video when off screen
        videoPlayer.pause(endKind: .pause)
    }

    var nova_isFullyVisibleOnScreen: Bool {
        // Placeholder implementation - should check if view is fully visible
        return true
    }
}

// MARK: - private function

@MainActor
private extension NovaAdVideoView {
    func syncVideoPlayerState(_ state: NovaAdVideoState) {
        videoPlayer.setPlayerMute(state.isMute)
        switch state.playState {
        case .showCover(let autoPlay, _):
            if autoPlay, !willAutoPlayingAfterShowCover {
                willAutoPlayingAfterShowCover = true
                startPlaying(after: 1.0)
            }
        case .loading:
            startPlaying()
        case .playing(let currentTime, _):
            if !currentTime.isIndefinite {
                videoPlayer.seek(to: currentTime, completionHandler: nil)
            }
            // TODO: lsy, 感觉这个后面不一定是 `startAutoPlayInFeed` 了
            resumeVideo(resumeKind: .startAutoPlayInFeed)
        case .paused(let currentTime, _, _):
            if !currentTime.isIndefinite {
                videoPlayer.seek(to: currentTime, completionHandler: nil)
            }
            resumeVideo(resumeKind: .resume)
        case .endPlaying:
            break
        }
    }

    func startPlayingFromBeginning() {
        videoPlayer.seek(to: .zero, completionHandler: nil)
        startPlaying()
    }

    func startPlaying(after seconds: TimeInterval? = nil) {
        let startVideoPlaying = {
            if self.startTime == nil {
                self.startTime = CACurrentMediaTime()
                self.lastResumeTime = self.startTime
            }
            self.videoPlayer.delegate = self
            self.videoPlayer.play()
        }

        if let seconds {
            let key = CACurrentMediaTime()
            showCoverKey = key
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
                if key != self?.showCoverKey {
                    return
                }
                startVideoPlaying()
            }
        } else {
            startVideoPlaying()
        }
    }

    func resumeVideo(resumeKind: VideoResumeKind) {
        videoPlayer.delegate = self
        videoPlayer.play()
        iabReporter?.logVideoResume()
        let resumeTime = CACurrentMediaTime()
        if let encryptedAdToken = actionContext?.adActionTracingInfo.encryptedAdToken,
           let lastPauseTime, resumeKind == .resume
        {
            NovaAdVideoMetricReporter.logVideoResume(
                encryptedAdToken: encryptedAdToken,
                duration: resumeTime - lastPauseTime,
                videoInfo: mediaModel?.videoInfo,
                startTime: startTime,
                configTime: configTime,
                novaVideoPlayer: videoPlayer
            )
        }
        lastResumeTime = resumeTime
    }

    func pauseVideo(endKind: NovaVideoEndKind) {
        videoPlayer.pause(endKind: endKind)
        iabReporter?.logVideoPause()
        lastPauseTime = CACurrentMediaTime()
    }

    func setupPlayer(videoInfo: NovaNativeAdVideoInfo) async {
        guard let videoUrl = URL(string: videoInfo.videoUrlStr) else {
            assertionFailure("Invalid video url: \(videoInfo.videoUrlStr)")
            return
        }

        let asset = await NovaAdVideoCacheManager.shared.loadAsset(url: videoUrl)
        self.configTime = CACurrentMediaTime()
        if let encryptedAdToken = self.actionContext?.adActionTracingInfo.encryptedAdToken {
            NovaAdVideoMetricReporter.makeRecord(encryptedAdToken: encryptedAdToken)
        }
        let playInfo = NovaPlayInfo(
            url: videoUrl,
            asset: asset,
            playLoops: videoInfo.isLoop,
            videoDataModel: nil,
            playStyle: .feed,
            isMute: videoInfo.isMute,
            disableGesture: true
        )
        videoPlayer.play(with: playInfo, actionHandler: nil, delegate: self)
    }

    func setupActionHelper() {
        guard let actionContext else {
            DebugLogger.ui.info("video media model is not clickable without action Context, but tapped")
            return
        }
        guard let mediaModel else {
            DebugLogger.ui.info("video media model is not set, but image tapped")
            return
        }
        guard actionHelper == nil else {
            return
        }

        if let weakVC = actionContext.viewController {
            actionHelper = NovaActionHelper
                .build(
                    with:
                    .adInViewController(
                        model: .init(
                            tracingInfo: actionContext.adActionTracingInfo,
                            extraInfo: actionContext.adActionExtraInfo,
                            ctrType: mediaModel.adCtrType
                        ),
                        viewController: weakVC
                    )
                )
        } else {
            actionHelper = NovaActionHelper
                .build(
                    with:
                    .adInView(
                        model: .init(
                            tracingInfo: actionContext.adActionTracingInfo,
                            extraInfo: actionContext.adActionExtraInfo,
                            ctrType: mediaModel.adCtrType
                        )
                    )
                )
        }
    }

    func resetStyle(_ style: Style) {
        self.subviewHandler?.removeViewsFromSuperview()
        subviewHandler = NovaNativeAdVideoSubviewHandlerCreator.create(with: style, delegate: self)
        subviewHandler?.setup(on: self)
        setupTapGesture()
    }

    @objc func didClickAd() {
        guard let mediaModel else {
            DebugLogger.ui.info("video media model is not set, but ad tapped")
            return
        }

        switch mediaModel.adCtrType {
        case .openWeb, .appInstall:
            actionHelper = actionHelper?.logNovaClickEvent(in: .media).handleAdTap(in: self)
        case .playable(let model):
            actionHelper = actionHelper?.logNovaPlayableAdTapToTryEvent(reason: .click).handleAdTap(in: self)
        }
    }

    @objc func didTapVideo(_ gesture: UITapGestureRecognizer) {
        switch style {
        case .landingPage:
            subviewHandler?.toggleAllSubViewVisibility(completion: { [weak self] currentHideStatus in
                if currentHideStatus {
                    dispatchCancel(block: self?.delayedHideViewBlock)
                } else {
                    self?.delayedHideViewBlock = dispatchMainAsyncAfter(
                        delay: 3.0,
                        block: DispatchWorkItem(block: { [weak self] in
                            self?.subviewHandler?.toggleAllSubViewVisibility(completion: nil)
                        })
                    )
                }
            })
        case .playButtonOnCenter(progressBarStyle: _):
            let location = gesture.location(in: self)
            if videoPlayer.isVideoPlaying() {
                isPausedByUser = true
                pauseVideo(endKind: .pause)
                subviewHandler?.tapVideo(on: self, at: location, isPlaying: false)
            } else {
                isPausedByUser = false
                resumeVideo(resumeKind: .resume)
                subviewHandler?.tapVideo(on: self, at: location, isPlaying: true)
            }
        case .clear, .playButtonOnLeftBottom:
            break
        }
    }

    private func setupTapGesture() {
        guard let mediaModel else { return }

        switch style {
        case .landingPage:
            isUserInteractionEnabled = true
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapVideo(_:))))
        case .playButtonOnCenter(progressBarStyle: _):
            isUserInteractionEnabled = true
            if mediaModel.videoInfo.isVideoClickable {
                addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didClickAd)))
            } else {
                addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapVideo(_:))))
            }
        case .clear, .playButtonOnLeftBottom:
            if mediaModel.videoInfo.isVideoClickable {
                addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didClickAd)))
            }
        }
    }

    private var shouldShowEndCard: Bool {
        if case .landingPage = style {
            return false
        }

        return mediaModel?.endCardModel != nil
    }

    private func configEndCard() {
        guard shouldShowEndCard, let endCardModel = mediaModel?.endCardModel else {
            return
        }

        endCard.config(with: endCardModel)
        addSubview(endCard)
        endCard.snp.makeConstraints { make in
            make.directionalEdges.equalToSuperview()
        }
        endCard.isHidden = true
        for endCardTappableView in endCard.clickableViews() {
            endCardTappableView.addGestureRecognizer(
                UITapGestureRecognizer(target: self, action: #selector(didClickAd))
            )
        }
    }
}

// MARK: - VideoPlayerDelegate

extension NovaAdVideoView: NovaVideoPlayerDelegate {
    func playerBufferTimeDidChange(_ bufferTime: Double) {}

    func playerReady(_ player: NovaPlayer) {}

    func playerPlaybackStateDidChange(_ player: NovaPlayer) {
        guard let videoInfo = mediaModel?.videoInfo else {
            return
        }

        switch player.playbackState {
        case .playing:
            videoInfo.didStart = true
            // NOTE: video player has a bug (line 393), when you play the video from paused state, play state did change will be called twice
            if case .playing = state?.playState {
                break
            }
            state = .init(
                playState:
                .playing(
                    currentTime: videoPlayer.currentTime(),
                    videoLength: videoPlayer.maximumTimeDuration()
                ),
                isMute: state?.isMute ?? true
            )
            videoStartPlayingAfterFinishLoading = true
        case .stopped:
            let shouldShowPlayButton: Bool = {
                switch style {
                // TODO: lsy, why there is not a `shouldShowPlayButton` property before?, 关于 end card

                case .clear, .playButtonOnLeftBottom, .playButtonOnCenter(progressBarStyle: _):
                    return videoInfo.endCardStyle == nil
                case .landingPage:
                    return true
                }
            }()
            state = .init(
                playState: .endPlaying(shouldShowPlayButton: shouldShowPlayButton),
                isMute: state?.isMute ?? true
            )
        case .paused:
            state = .init(
                playState:
                .paused(
                    currentTime: videoPlayer.currentTime(),
                    videoLength: videoPlayer.maximumTimeDuration(),
                    endKind: videoPlayer.getVideoEndKind()
                ),
                isMute: state?.isMute ?? true
            )
            if let encryptedAdToken = actionContext?.adActionTracingInfo.encryptedAdToken, let lastResumeTime {
                let duration = CACurrentMediaTime() - lastResumeTime
                let reason: NovaAdVideoMetricReporter.NovaAdEventPauseReason? = {
                    switch videoPlayer.getVideoEndKind() {
                    case .pause:
                        return .manual
                    case .none:
                        return .auto
                    default:
                        return nil
                    }
                }()
                NovaAdVideoMetricReporter
                    .logVideoPause(
                        encryptedAdToken: encryptedAdToken,
                        duration: duration,
                        reason: reason,
                        videoInfo: videoInfo,
                        startTime: startTime,
                        configTime: configTime,
                        novaVideoPlayer: videoPlayer
                    )
            }
        default:
            break
        }
    }

    func playerBufferTimeDidChange(_ player: NovaPlayer, bufferTime: Double) {}

    func playerCurrentTimeDidChange(_ player: NovaPlayer) {
        let videoCurrent = videoPlayer.currentTime()
        let videoCurrentTimeInterval = videoPlayer.currentTimeInterval()
        let videoLength = player.maximumDuration
        if videoCurrent.isIndefinite || videoLength.isNaN {
            return
        }
        switch state?.playState {
        case .playing(currentTime: _, _):
            if videoStartPlayingAfterFinishLoading {
                videoStartPlayingAfterFinishLoading = false
                delegate?.videoViewDidChangeToPlay()
            }
            state = .init(
                playState: .playing(currentTime: videoCurrent, videoLength: videoLength),
                isMute: state?.isMute ?? true
            )
        case .paused(currentTime: _, _, _):
            let endKind: NovaVideoEndKind = {
                if let state, case .paused(_, _, let endKind) = state.playState {
                    return endKind
                } else {
                    return .none
                }
            }()
            state = .init(
                playState: .paused(currentTime: videoCurrent, videoLength: videoLength, endKind: endKind),
                isMute: state?.isMute ?? true
            )
        default:
            break
        }

        delegate?
            .videoViewCurrentTimeDidChange(
                loopCount: loopCount,
                currentTime: videoCurrentTimeInterval,
                videoLength: videoLength
            )

        guard let videoInfo = mediaModel?.videoInfo else { return }
        guard let encryptedAdToken = self.actionContext?.adActionTracingInfo.encryptedAdToken else { return }

        if let startTime, let configTime {
            NovaAdVideoMetricReporter.logVideoStart(
                encryptedAdToken: encryptedAdToken,
                videoInfo: videoInfo,
                startTime: startTime,
                configTime: configTime,
                novaVideoPlayer: videoPlayer
            )
            iabReporter?.logVideoStart(duration: videoCurrentTimeInterval, volume: videoPlayer.isPlayerMuted() ? 0.0 : 1.0)
        }
        NovaAdVideoMetricReporter.logVideoProgress(encryptedAdToken: encryptedAdToken,
                                                   percentage: videoCurrentTimeInterval / videoLength,
                                                   duration: videoCurrentTimeInterval)
        iabReporter?.logVideoProgress(percentage: videoCurrentTimeInterval / videoLength)
    }

    func playerTimePassed60sAfterPlay(_ player: NovaPlayer) {}

    func player(_ player: NovaPlayer, didFailWithError error: Error?) {
        if let encryptedAdToken = actionContext?.adActionTracingInfo.encryptedAdToken, let configTime {
            NovaAdVideoMetricReporter.logVideoError(encryptedAdToken: encryptedAdToken,
                                                    error: error?.localizedDescription ?? "",
                                                    duration: CACurrentMediaTime() - configTime)
        }
    }

    func playerPlaybackWillLoop(_ player: NovaPlayer) {
        loopCount += 1
    }

    func playerPlaybackDidLoop(_ player: NovaPlayer) {}

    func playerDidPlayToEndTime(_ player: NovaPlayer) {
        if shouldShowEndCard {
            endCard.isHidden = false
            // TODO: lsy, should we stop the video player here?
        }
        delegate?.videoViewDidPlayToEndTime()
    }
}

extension NovaAdVideoView: NovaAdVideoSubviewBehaviorDelegate {
    func didTapStartButton() {
        startPlaying()
    }

    func didTapMuteButton() {
        guard state != nil else {
            return
        }

        let currentMuteState = videoPlayer.isPlayerMuted()
        muted = !currentMuteState
        if let encryptedAdToken = actionContext?.adActionTracingInfo.encryptedAdToken {
            NovaAdVideoMetricReporter.logVideoMute(encryptedAdToken: encryptedAdToken,
                                                   isMute: videoPlayer.isPlayerMuted())
        }
        iabReporter?.logVideoVolumeChange(to: !currentMuteState ? 0.0 : 1.0)
    }

    func didTapPlayButton(_ gesture: UITapGestureRecognizer) {
        if videoPlayer.isVideoPlaying() {
            isPausedByUser = true
            pauseVideo(endKind: .pause)
        } else {
            isPausedByUser = false
            resumeVideo(resumeKind: .resume)
        }
    }

    func didTapCloseButton() {
        delegate?.videoViewDidTapCloseButton()
    }

    func didTapAd(on clickArea: ClickableAdArea) {
        actionHelper = actionHelper?.logNovaClickEvent(in: clickArea).handleAdTap(in: self)
    }
}

extension NovaAdVideoView: NovaAdEndCardDelegate {
    func endCardDidTapCloseButton() {
        endCard.isHidden = true
    }

    func endCardDidTapWatchAgainButton() {
        endCard.isHidden = true
        startPlayingFromBeginning()
    }
}
