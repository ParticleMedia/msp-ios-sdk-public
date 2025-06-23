
import AVFoundation
import UIKit

public class NovaVideoPlayer: NSObject {

    static let urlToStopLoading = "https://www.newsbreak.com"

    public weak var delegate: NovaVideoPlayerDelegate?
    public let player = NovaPlayer()
    private var url: URL?
    private var actionHandler: ActionHandling?

    private var playStyle: NovaVideoPlayStyle = .none

    private var tapGestureRecognizer: UITapGestureRecognizer?

    private var isDragging = false
    private var isSeeking = false

    private var videoStart: Date?
    private var localProgress = 0.0
    private var localTimeElapsed: TimeInterval = 0
    private var videoStartToload: Date?
    private var localLoadingTimeElapsed = 0 // ms
    private var videoEndKind: NovaVideoEndKind = .none

    private let loadingIndicatorView: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView()
        indicator.style = .whiteLarge
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private let indicatorWidth = 37.0

    private var videoPlayingTimer: Timer?
    private var shouldSendVideoLog = false

    private var trackViewLeftConstraint: NSLayoutConstraint!

    private var isPlaying: Bool = false {
        didSet {
            if isPlaying {
                isloading = false
                configPlayerImageView(isHidden: true)
            }
        }
    }

    private var isloading: Bool = false {
        didSet {
            if isloading {
                loadingIndicatorView.isHidden = false
                loadingIndicatorView.startAnimating()
                configPlayerImageView(isHidden: true)
            } else {
                loadingIndicatorView.isHidden = true
                loadingIndicatorView.stopAnimating()
            }
        }
    }

    private var callingStop = false

    override public init() {
        super.init()
        player.autoplay = false
        player.playerDelegate = self
        player.playbackDelegate = self
        player.view.frame = .zero
        player.playerView.playerBackgroundColor = .black
        player.fillMode = .resizeAspect
        player.playbackLoops = true
        player.playbackResumesWhenEnteringForeground = false
        player.playbackResumesWhenBecameActive = false

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGestureRecognizer(_:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        self.player.view.addGestureRecognizer(tapGestureRecognizer)
        self.tapGestureRecognizer = tapGestureRecognizer

        configPlayerImageView(isHidden: true)
        isloading = false

        player.view.addSubview(loadingIndicatorView)

        NSLayoutConstraint.activate([
            loadingIndicatorView.centerXAnchor.constraint(equalTo: player.view.centerXAnchor),
            loadingIndicatorView.centerYAnchor.constraint(equalTo: player.view.centerYAnchor),
            loadingIndicatorView.widthAnchor.constraint(equalToConstant: indicatorWidth),
            loadingIndicatorView.heightAnchor.constraint(equalToConstant: indicatorWidth),
        ])
    }

    public func configDisplay(_ display: Bool) {
        if player.view.isHidden == display {
            player.view.isHidden = !display
        }
    }

    public func currentTime() -> CMTime {
        return player.currentTime
    }

    public func currentTimeInterval() -> TimeInterval {
        return player.currentTimeInterval
    }
    
    public func maximumTimeDuration() -> TimeInterval {
        return player.maximumDuration
    }

    public func isVideoPlaying() -> Bool {
        return isPlaying
    }

    public func isVideoLoading() -> Bool {
        return isloading
    }

    public func toggleVideoPlay() {
        self.adjustVideoPlayerStatus()
    }

    public func videoPlayedTimeElapsed() -> TimeInterval {
        return localTimeElapsed
    }

    public func getVideoStartTime() -> Date? {
        return videoStart
    }

    public func getCurrentProgress() -> Double {
        let duration = player.maximumDuration
        var progress: CGFloat = 0.0
        let currentTime = CMTimeGetSeconds(player.currentTime)
        if currentTime > 0 && duration > 0 {
            progress = CMTimeGetSeconds(player.currentTime) / Double(duration)
            progress = progress > 1 ? 1 : progress
            if progress > localProgress {
                localProgress = progress
            } else {
                progress = localProgress
            }
        } else {
            progress = localProgress >= 0 ? localProgress : 0
        }

        return progress
    }
    
    public func getRealProgress() -> Double {
        let duration = player.maximumDuration
        let currentTime = CMTimeGetSeconds(player.currentTime)
        return Double(currentTime).truncatingRemainder(dividingBy: duration) / Double(duration)
    }

    public func addUpLocalTimeElapsed(){
        if let videoStart = videoStart {
            let time = Date().timeIntervalSince(videoStart)
            if time > 0.001 {
                localTimeElapsed += time
            }
        }
    }

    public func getVideoEndKind() -> NovaVideoEndKind {
        return self.videoEndKind
    }

    public func getLoadingTimeElapsed() -> Int {
        return localLoadingTimeElapsed
    }

    private func adjustVideoPlayerStatus() {
        guard isloading == false else { return }
        switch self.player.playbackState {
        case .stopped:
            self.player.playFromBeginning()
            break
        case .paused:
            self.player.playFromCurrentTime()
            break
        case .playing:
            self.player.pause()
            break
        case .failed:
            self.player.pause()
            break
        }
    }

    private func setProgress(_ progress: Float) {

    }
}

extension NovaVideoPlayer {
    @objc func handleTapGestureRecognizer(_ gestureRecognizer: UITapGestureRecognizer) {
        self.adjustVideoPlayerStatus()
    }

    private func configPlayerImageView(isHidden: Bool) {

    }
}

extension NovaVideoPlayer: NovaVideoPlayerProtocol {
    public func isPlayerMuted() -> Bool {
        return player.muted
    }

    public func setPlayerMute(_ mute: Bool) {
        player.muted = mute
    }

    public func play() {
        isloading = player.bufferingState != .ready
        //DebugLogging.info(.video, "VideoPlayer Inside playFromCurrentTime")
        videoEndKind = .none
        player.playFromCurrentTime()
    }

    public func pause(endKind: NovaVideoEndKind) {
        //DebugLogging.info(.video, "VideoPlayer Inside pause")
        videoEndKind = endKind
        player.pause()
    }

    public func stop(endKind: NovaVideoEndKind) {
        //DebugLogging.info(.video, "VideoPlayer Inside stop")
        callingStop = true
        videoEndKind = endKind
        player.stop()
        callingStop = false
        localTimeElapsed = 0
    }

    public func endPlay(endKind: NovaVideoEndKind) {
        //DebugLogging.info(.video, "VideoPlayer Inside stop")
        if player.playbackState == .stopped { return }
        callingStop = true
        player.stop()
        player.view.removeFromSuperview()
        videoPlayingTimer?.invalidate()
        self.delegate = nil
        callingStop = false
        localTimeElapsed = 0
        if endKind == .stopLoadingCache {
            self.player.url = URL(string: NovaVideoPlayerController.urlToStopLoading)
        }
    }

    public func isPlaying(urlString: String) -> Bool {
        return player.url?.absoluteString == urlString
    }

    public func seek(to time: CMTime, completionHandler: ((Bool) -> Void)?) {
        player.seek(to: time, completionHandler: completionHandler)
    }

    public func play(with info: NovaPlayInfo,
                     actionHandler: ActionHandling?,
                     delegate: NovaVideoPlayerDelegate) {
        //DebugLogging.info(.video, "VideoPlayer Inside play")
        self.actionHandler = actionHandler
        if player.url?.absoluteString != info.url.absoluteString {
            url = info.url
            player.url = url
            localTimeElapsed = 0
        }
        shouldSendVideoLog = true
        videoEndKind = .none
        videoStart = nil
        videoStartToload = Date()
        self.delegate = delegate
        player.playbackLoops = info.playLoops
        playStyle = info.playStyle
        player.muted = info.isMute
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        self.tapGestureRecognizer?.isEnabled = !info.disableGesture

        self.setProgress(0)
        configPlayerImageView(isHidden: true)
    }

    public func update(fillMode: AVLayerVideoGravity) {
        player.fillMode = fillMode
    }

    public func preload(with url: URL) {
        shouldSendVideoLog = false
        self.url = url
        player.url = url
        self.setProgress(0)
        isloading = true
        player.stop()
    }

    public func getPlayerView() -> UIView {
        return self.player.view
    }

    private func _playerStateDidChange(_ player: NovaPlayer) {
        let videoLoadDuration = Double(player.maximumDuration)

        switch player.playbackState {
        case .playing:
            videoStart = Date()
            if let videoStartToload = videoStartToload {
                self.videoStartToload = nil
                localLoadingTimeElapsed = Int(ceil(Date().timeIntervalSince(videoStartToload) * 1000))
            }
            break

        case .paused:
            guard callingStop == false && videoLoadDuration > 0 else { return }
            isPlaying = false
            videoPlayingTimer?.invalidate()
            configPlayerImageView(isHidden: self.isSeeking)
            break

        case .stopped:
            guard videoLoadDuration > 0 else { return }
            isPlaying = false
            videoPlayingTimer?.invalidate()
            self.setProgress(0)
            break

        case .failed: break

        }

        self.delegate?.playerPlaybackStateDidChange(player)

        if player.playbackState != .playing {
            videoStart = nil
        }
    }
}

extension NovaVideoPlayer: NovaPlayerDelegate {
    public func playerReady(_ player: NovaPlayer) {
        self.delegate?.playerReady(player)
    }

    public func playerPlaybackStateDidChange(_ player: NovaPlayer) {
        _playerStateDidChange(player)
    }

    public func playerBufferingStateDidChange(_ player: NovaPlayer) {

    }

    public func playerBufferTimeDidChange(_ bufferTime: Double) {
        self.delegate?.playerBufferTimeDidChange(bufferTime)
    }

    public func player(_ player: NovaPlayer, didFailWithError error: Error?) {
        self.delegate?.player(player, didFailWithError: error)
    }
}

extension NovaVideoPlayer: NovaPlayerPlaybackDelegate {
    public func playerCurrentTimeDidChange(_ player: NovaPlayer) {
        if player.currentTimeInterval > 0 {
            self.configDisplay(true)
        }
        if !isDragging && !isSeeking && player.playbackState == .playing {
            let fraction = Float(CMTimeGetSeconds(player.currentTime) / Double(player.maximumDuration))
            self.setProgress(fraction)
        }
        if isPlaying == false,
           player.playbackState == .playing,
           player.currentTimeInterval > 0 {
            isPlaying = true
            videoPlayingTimer?.invalidate()
            _playerStateDidChange(player)
            videoPlayingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true, block: { [weak self] _ in
                self?.delegate?.playerTimePassed60sAfterPlay(player)
            })
        }
        self.delegate?.playerCurrentTimeDidChange(player)
    }

    public func playerPlaybackWillStartFromBeginning(_ player: NovaPlayer) {

    }

    public func playerPlaybackDidEnd(_ player: NovaPlayer) {

    }

    public func playerPlaybackWillLoop(_ player: NovaPlayer) {
        localProgress = 1.0
        self.delegate?.playerPlaybackWillLoop(player)

    }

    public func playerPlaybackDidLoop(_ player: NovaPlayer) {
        videoStart = Date()
        self.delegate?.playerPlaybackDidLoop(player)
    }
    
    public func playerDidPlayToEndTime(_ player: NovaPlayer) {
        self.delegate?.playerDidPlayToEndTime(player)
    }
}
