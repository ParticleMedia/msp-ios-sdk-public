//
//  NovaAdVideoView.swift
//  NBNovaAds
//
//  Created by Felix Dai on 2022/9/20.
//
import CoreMedia
@_implementationOnly import MSPSnapKit
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
        case playButtonOnCenter(progressBarStyle: ProgressBarStyle, popupCTAStyle: PopupCTAStyle)
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

        public enum PopupCTAStyle: Equatable {
            case hide
            case show(safeAreaInsets: UIEdgeInsets = .zero, exclusionRects: [CGRect] = [])
        }

        public static func == (lhs: NovaAdVideoView.Style, rhs: NovaAdVideoView.Style) -> Bool {
            switch (lhs, rhs) {
            case (.clear, .clear):
                return true
            case (.playButtonOnLeftBottom, .playButtonOnLeftBottom):
                return true
            case (
                .playButtonOnCenter(let lhsProgressBarStyle, let lhsPopupCTAStyle),
                .playButtonOnCenter(let rhsProgressBarStyle, let rhsPopupCTAStyle)
            ):
                return lhsProgressBarStyle == rhsProgressBarStyle && lhsPopupCTAStyle == rhsPopupCTAStyle
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

    var muted: Bool {
        get {
            mediaModel?.videoInfo.state?.isMute ?? mediaModel?.videoInfo.isMute ?? true
        }
        set {
            let oldValue = muted
            videoPlayer.setPlayerMute(newValue)
            if oldValue != newValue {
                reportMute(currentMuteState: newValue)
                mediaModel?.videoInfo.state?.updateMuteState(newValue)
                notifyStateDidChange()
            }
        }
    }

    // MARK: Private

    private var subviewHandler: (any NovaNativeAdVideoSubviewHandler)? = nil
    private var delayedHideViewBlock: DispatchCancelableBlock?

    private var videoPlayer: NovaVideoPlayer = .init()

    private var willAutoPlayingAfterShowCover: Bool = false

    private var mediaModel: NovaAdVideoMediaModel?
    private var actionContext: NovaAdMediaActionContext?

    private var showCoverKey: Double?
    private var videoStartPlayingAfterFinishLoading = false

    private var configTime: Double? = nil
    private var startTime: Double? = nil

    private var actionHelper: NovaActionHelper<NovaActionState.Init>?

    private weak var iabReporter: IABMetricReporter?

    private var isPausedByUser = false

    weak var mediaContent: NovaAdMediaContent?

    // MARK: - Subviews

    private lazy var endCard: NovaAdEndCard = .init(delegate: self)

    private var bottomShadowView: GradientShadowView?

    private var state: NovaAdVideoState? {
        mediaModel?.videoInfo.state
    }

    /// Notify side effects after mutating state in place.
    private func notifyStateDidChange() {
        guard let state else { return }
        if case .showCover = state.playState {
        } else {
            willAutoPlayingAfterShowCover = false
        }
        mediaContent?.updateVideoState(state)
        subviewHandler?.sync(with: state)
    }

    private var loopCount: Int = 0 {
        didSet {
            if oldValue != loopCount {
                mediaModel?.videoInfo.state?.updateLoopCount(loopCount)
            }
        }
    }
}

// MARK: - function

extension NovaAdVideoView {
    func config(
        with model: NovaAdVideoMediaModel,
        actionContext: NovaAdMediaActionContext?,
        iabReporter: IABMetricReporter?,
        showBottomShadow: Bool = false
    ) {
        self.mediaModel = model
        self.actionContext = actionContext
        self.iabReporter = iabReporter
        self.loopCount = mediaModel?.videoInfo.state?.loopCount ?? 0

        setupPlayer(videoInfo: model.videoInfo)

        if model.videoInfo.state == nil {
            if let coverUrlStr = model.videoInfo.coverUrlStr, let url = URL(string: coverUrlStr) {
                mediaModel?.videoInfo.state = .init(
                    playState: .showCover(autoPlay: model.videoInfo.isAuto, coverURL: url),
                    isMute: model.videoInfo.isMute)
            } else {
                mediaModel?.videoInfo.state = .init(
                    playState: model.videoInfo.isAuto ? .loading : .endPlaying(shouldShowPlayButton: true),
                    isMute: model.videoInfo.isMute
                )
            }
        }
        notifyStateDidChange()
        muted = model.videoInfo.state?.isMute ?? model.videoInfo.isMute
        setupActionHelper()
        setupTapGesture()
        configEndCard()
        subviewHandler?.config(with: model)
        setupBottomShadow(showBottomShadow: showBottomShadow)
    }

    func prepareForReuse() {
        videoPlayer.stop(endKind: .none)
        willAutoPlayingAfterShowCover = false
        isPausedByUser = false
        mediaModel = nil
        videoStartPlayingAfterFinishLoading = false
        bottomShadowView?.removeFromSuperview()
        bottomShadowView = nil
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

        switch playStrategy {
        case .fromBeginning:
            startPlayingFromBeginning()
        case .continueFromLast:
            if let state {
                syncVideoPlayerState(state)
            }
        }
    }

    func pause() {
        guard let playState = mediaModel?.videoInfo.state?.playState else {
            assertionFailure("lack state info")
            return
        }

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
        videoPlayer.stop(endKind: .none)
        videoPlayer.player.playbackLoops = false
        videoPlayer.player.playbackFreezesAtEnd = true
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
        true
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
            videoPlayerSeekTo(currentTime)
            resumeVideo(resumeKind: .startAutoPlayInFeed)
        case .paused(let currentTime, _, let endKind):
            videoPlayerSeekTo(currentTime)
            let resumeKind: VideoResumeKind = (endKind == .pause) ? .resume : .startAutoPlayInFeed
            resumeVideo(resumeKind: resumeKind)
        case .endPlaying:
            break
        }
    }

    func startPlayingFromBeginning() {
        videoPlayer.seek(to: .zero, completionHandler: nil)
        startPlaying()
    }

    private func videoPlayerSeekTo(_ currentTime: CMTime) {
        // Normalize CMTime to valid bounds before seeking
        let normalizedTime = normalizeSeekTime(currentTime)
        videoPlayer.seek(to: normalizedTime, completionHandler: nil)
    }

    /// Normalizes a CMTime to valid bounds for seeking operations
    ///
    /// - Parameter time: The CMTime to normalize
    /// - Returns: A valid CMTime within bounds
    private func normalizeSeekTime(_ time: CMTime) -> CMTime {
        // Handle invalid times (check if time is kCMTimeInvalid)
        if CMTimeCompare(time, CMTime.invalid) == 0 {
            // Fallback to current playback position or zero
            let currentTime = videoPlayer.currentTime()
            if CMTimeCompare(currentTime, CMTime.invalid) != 0 && CMTimeCompare(currentTime, CMTime.indefinite) != 0 {
                return currentTime
            }
            return .zero
        }

        // Handle indefinite times (check if time is kCMTimeIndefinite)
        if CMTimeCompare(time, CMTime.indefinite) == 0 {
            // Fallback to current playback position or zero
            let currentTime = videoPlayer.currentTime()
            if CMTimeCompare(currentTime, CMTime.invalid) != 0 && CMTimeCompare(currentTime, CMTime.indefinite) != 0 {
                return currentTime
            }
            return .zero
        }

        // Only clamp negative times to zero (preserve precision for valid times)
        if CMTimeCompare(time, .zero) < 0 {
            return .zero
        }

        // For times beyond duration, use the original time if it's close to duration
        // Only clamp if significantly beyond duration
        let duration = videoPlayer.maximumTimeDuration()
        if duration > 0 {
            let maxTime = CMTime(value: Int64(duration * 1000), timescale: 1000)
            // Only clamp if significantly beyond (more than 1 second beyond)
            let oneSecond = CMTime(value: 1000, timescale: 1000)
            let threshold = CMTimeAdd(maxTime, oneSecond)
            if CMTimeCompare(time, threshold) > 0 {
                return maxTime
            }
        }

        return time
    }

    func startPlaying(after seconds: TimeInterval? = nil) {
        setupStartTime(delayTime: seconds)
        let startVideoPlaying = { [weak self] in
            guard let self else { return }
            guard !self.videoPlayer.isVideoPlaying() else { return }
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
        setupStartTime()
        videoPlayer.delegate = self
        videoPlayer.play()
        iabReporter?.logVideoResume()
        if let actionContext {
            let encryptedAdToken = actionContext.adActionTracingInfo.encryptedAdToken
            let reason: NovaAdVideoMetricReporter.NovaAdEventPauseReason =
                switch resumeKind {
                case .resume:
                    .manual
                case .startAutoPlayInFeed:
                    .auto
                }
            NovaAdVideoMetricReporter.logVideoResume(
                encryptedAdToken: encryptedAdToken,
                reason: reason
            )
        }
    }

    private func setupStartTime(delayTime: TimeInterval? = nil) {
        if startTime == nil {
            startTime = CACurrentMediaTime() + (delayTime ?? 0.0)
        }
    }

    func pauseVideo(endKind: NovaVideoEndKind) {
        videoPlayer.pause(endKind: endKind)
        iabReporter?.logVideoPause()
    }

    func setupPlayer(videoInfo: NovaNativeAdVideoInfo) {
        guard let videoUrl = URL(string: videoInfo.videoUrlStr) else {
            assertionFailure("Invalid video url: \(videoInfo.videoUrlStr)")
            return
        }

        self.configTime = CACurrentMediaTime()
        if let actionContext {
            let encryptedAdToken = actionContext.adActionTracingInfo.encryptedAdToken
            NovaAdVideoMetricReporter.makeRecord(encryptedAdToken: encryptedAdToken)
        }
        let playInfo = NovaPlayInfo(
            url: videoUrl,
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
            actionHelper =
                NovaActionHelper
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
            actionHelper =
                NovaActionHelper
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
        case .playable(_):
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

    private func setupBottomShadow(showBottomShadow: Bool) {
        bottomShadowView?.removeFromSuperview()
        bottomShadowView = nil

        guard showBottomShadow else {
            return
        }

        // Use fixed shadow configuration
        let config = GradientShadowViewConfig(
            colors: (
                UIColor.clear,
                UIColor.black.withAlphaComponent(0.85)
            ),
            points: (CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1.0)),
            shadowColor: .clear,
            shadowOpacity: 0,
            shadowOffset: .zero,
            shadowRadius: 0
        )

        let shadowView = GradientShadowView(with: config)
        shadowView.isUserInteractionEnabled = false
        addSubview(shadowView)

        // Place shadow above playerView but below popup CTA
        let playerView = videoPlayer.getPlayerView()
        insertSubview(shadowView, aboveSubview: playerView)

        shadowView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            // Default height similar to interstitial handlers
            let screenWidth = UIScreen.main.bounds.width
            make.height.equalTo(screenWidth * 280 / 375)
        }

        bottomShadowView = shadowView
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
            mediaModel?.videoInfo.state?.transition(
                to: .playing(
                    currentTime: videoPlayer.currentTime(),
                    videoLength: videoPlayer.maximumTimeDuration()
                )
            )
            notifyStateDidChange()
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
            mediaModel?.videoInfo.state?.transition(
                to: .endPlaying(shouldShowPlayButton: shouldShowPlayButton)
            )
            notifyStateDidChange()
        case .paused:
            mediaModel?.videoInfo.state?.transition(
                to: .paused(
                    currentTime: videoPlayer.currentTime(),
                    videoLength: videoPlayer.maximumTimeDuration(),
                    endKind: videoPlayer.getVideoEndKind()
                )
            )
            notifyStateDidChange()
            if let actionContext {
                let encryptedAdToken = actionContext.adActionTracingInfo.encryptedAdToken
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
                        reason: reason,
                        loopCount: loopCount,
                        positionTime: videoPlayer.currentTimeInterval(),
                        videoLength: videoPlayer.maximumTimeDuration()
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
        case .playing:
            if videoStartPlayingAfterFinishLoading {
                videoStartPlayingAfterFinishLoading = false
                delegate?.videoViewDidChangeToPlay()
            }
            mediaModel?.videoInfo.state?.updatePlayingTime(
                currentTime: videoCurrent, videoLength: videoLength
            )
            notifyStateDidChange()
        case .paused:
            mediaModel?.videoInfo.state?.updatePausedTime(
                currentTime: videoCurrent, videoLength: videoLength
            )
            notifyStateDidChange()
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
        guard let actionContext else { return }

        let encryptedAdToken = actionContext.adActionTracingInfo.encryptedAdToken
        NovaAdVideoMetricReporter.trackVideoMediaTime(
            encryptedAdToken: encryptedAdToken,
            positionTime: videoCurrentTimeInterval,
            videoLength: videoLength,
            isPlaying: videoPlayer.isVideoPlaying(),
            loopCount: loopCount
        )

        // Log Start

        NovaAdVideoMetricReporter.logVideoStart(
            encryptedAdToken: encryptedAdToken,
            isAuto: videoInfo.isAuto,
            isMute: videoInfo.isMute,
            isLoop: videoInfo.isLoop,
            isVideoClickable: videoInfo.isVideoClickable,
            videoLength: videoLength,
            latency: startTime.flatMap { start in
                configTime.map { start - $0 }
            }
        )

        iabReporter?.logVideoStart(duration: videoCurrentTimeInterval, volume: videoPlayer.isPlayerMuted() ? 0.0 : 1.0)

        // Log End

        NovaAdVideoMetricReporter.logVideoEnd(
            encryptedAdToken: encryptedAdToken,
            percentage: videoCurrentTimeInterval / videoLength
        )

        // Log Progress

        NovaAdVideoMetricReporter.logVideoProgress(
            encryptedAdToken: encryptedAdToken,
            percentage: videoCurrentTimeInterval / videoLength,
            duration: videoCurrentTimeInterval)
        iabReporter?.logVideoProgress(percentage: videoCurrentTimeInterval / videoLength)
    }

    func playerTimePassed60sAfterPlay(_ player: NovaPlayer) {}

    func player(_ player: NovaPlayer, didFailWithError error: Error?) {
        if let actionContext {
            let encryptedAdToken = actionContext.adActionTracingInfo.encryptedAdToken
            NovaAdVideoMetricReporter.logVideoError(
                encryptedAdToken: encryptedAdToken,
                error: error?.localizedDescription ?? "")
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

        if let actionContext {
            let encryptedAdToken = actionContext.adActionTracingInfo.encryptedAdToken
            NovaAdVideoMetricReporter.logVideoEnd(
                encryptedAdToken: encryptedAdToken,
                percentage: 1.0
            )
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
    }

    func reportMute(currentMuteState: Bool) {
        if let actionContext {
            let encryptedAdToken = actionContext.adActionTracingInfo.encryptedAdToken
            NovaAdVideoMetricReporter.logVideoMute(
                encryptedAdToken: encryptedAdToken,
                isMute: currentMuteState)
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

    func didTapAd(on view: UIView) {
        actionHelper = actionHelper?.logNovaClickEvent(in: view.adClickArea).handleAdTap(in: view)
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

extension CMTime {
    var timeInterval: TimeInterval {
        CMTimeGetSeconds(self)
    }
}
