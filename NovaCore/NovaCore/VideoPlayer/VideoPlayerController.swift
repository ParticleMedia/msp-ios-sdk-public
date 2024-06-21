
import AVFoundation
import UIKit

public enum VideoEndKind: String {
    case none
    case pause
    case stopLoadingCache
    case stopAutoPlayInFeed
    case prepareForReuse
    case seek
    case close
    case scroll
    case pull
    case pageInvisible
    
    public func loggingString() -> String {
        switch self {
        case .none, .pause, .stopLoadingCache, .stopAutoPlayInFeed, .prepareForReuse, .seek:
            return "other_pause"
        case .pageInvisible:
            return "page_invisible"
        case .close:
            return "close"
        case .scroll:
            return "scroll"
        case .pull:
            return "pull"
        }
    }
}

public class VideoPlayerController: NSObject {

    static let urlToStopLoading = "https://www.newsbreak.com"

    weak var delegate: VideoPlayerDelegate?
    private let player = Player()
    private var url: URL?
    //private var dataModel: VideoDataModel?
    private var playStyle: VideoPlayStyle = .none

    private let progressPanGestrue = UIPanGestureRecognizer()
    private var tapGestureRecognizer: UITapGestureRecognizer?

    private var isDragging = false
    private var isSeeking = false {
        didSet {
            if isSeeking {
                progressBackgroundBar.setTrackView(hidden: false)
            } else {
                progressBackgroundBar.setTrackView(hidden: true)
            }
        }
    }

    private var actionHandler: ActionHandling?
    private var consumptionTimeStart: Date?
    private var localProgress = 0.0
    private var localTimeElapsed: TimeInterval = 0
    private var videoStartToload: Date?
    private var localLoadingTimeElapsed = 0 // ms
    private var videoEndKind: VideoEndKind = .none
    private var enableLogging = false

    private let playImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .center
        return imageView
    }()

    private let statusContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private let loadingIndicatorView: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.style = .whiteLarge
        return indicator
    }()

    private let indicatorWidth = 37.0

    public let progressBackgroundBar: VideoProgressView = {
        let view = VideoProgressView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var videoPlayingTimer: Timer?
    private var shouldSendVideoLog = false

    private var playImageWidth: NSLayoutConstraint!
    private var playImageHeight: NSLayoutConstraint!

    private var isPlaying: Bool = false {
        didSet {
            if isPlaying {
                isloading = false
                playImageView.isHidden = true
            }
        }
    }

    private var isloading: Bool = false {
        didSet {
            if isloading {
                loadingIndicatorView.isHidden = false
                loadingIndicatorView.startAnimating()
                playImageView.isHidden = true
            } else {
                loadingIndicatorView.isHidden = true
                loadingIndicatorView.stopAnimating()
            }
        }
    }

    private var isLoadSuccess = false

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

        progressPanGestrue.addTarget(self, action: #selector(handleProgressPanGestrue(_:)))
        progressPanGestrue.delegate = self
        progressBackgroundBar.addGestureRecognizer(progressPanGestrue)

        playImageView.isHidden = true
        isloading = false

        player.view.addSubview(statusContainer)
        statusContainer.addSubview(loadingIndicatorView)
        statusContainer.addSubview(playImageView)

        playImageWidth = playImageView.widthAnchor.constraint(equalToConstant: 100)
        playImageHeight = playImageView.heightAnchor.constraint(equalToConstant: 100)

        NSLayoutConstraint.activate([
            statusContainer.centerXAnchor.constraint(equalTo: player.view.centerXAnchor),
            statusContainer.centerYAnchor.constraint(equalTo: player.view.centerYAnchor),
            statusContainer.widthAnchor.constraint(equalToConstant: 200),
            statusContainer.heightAnchor.constraint(equalToConstant: 200),

            playImageView.centerXAnchor.constraint(equalTo: statusContainer.centerXAnchor),
            playImageView.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
            playImageWidth,
            playImageHeight,

            loadingIndicatorView.centerXAnchor.constraint(equalTo: statusContainer.centerXAnchor),
            loadingIndicatorView.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
            loadingIndicatorView.widthAnchor.constraint(equalToConstant: indicatorWidth),
            loadingIndicatorView.heightAnchor.constraint(equalToConstant: indicatorWidth),
        ])
    }

    public func configDisplay(_ display: Bool) {
        if player.view.isHidden == display {
            player.view.isHidden = !display
        }
    }

    public func configPlayImage(image: UIImage?, size: CGSize) {
        playImageView.image = image
        playImageWidth.constant = size.width
        playImageHeight.constant = size.height
    }

    public func currentTimeInterval() -> TimeInterval {
        return player.currentTimeInterval
    }

    public func isVideoPlaying() -> Bool {
        return isPlaying
    }

    public func toggleVideoPlay() {
        self.adjustVideoPlayerStatus()
    }

    public func videoPlayedTimeElapsed() -> TimeInterval {
        return localTimeElapsed
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

    @objc func handleProgressPanGestrue(_ pan: UIPanGestureRecognizer) {
        let duration = CGFloat(player.maximumDuration)
        guard duration > 0 else { return }

        let pos = pan.location(in: progressBackgroundBar)
        let percentage = pos.x / progressBackgroundBar.frame.width
        switch pan.state {
        case .began:
            isDragging = true
            break
        case .cancelled, .failed, .ended:
            isDragging = false
            let seektime = Int64(duration * percentage * 1000)
            let time = CMTimeMake(value: seektime, timescale: 1000)

            self.playImageView.isHidden = true
            self.isloading = true
            self.pause(endKind: .seek)

            self.seek(to: time) { [weak self] _ in
                guard let self = self else { return }
                self.isSeeking = false
                self.play()
            }

            break
        case .changed:
            isSeeking = true
            self.setProgress(Float(percentage))
        default:
            break
        }
    }

    private func setProgress(_ progress: Float) {
        progressBackgroundBar.updateProgress(progress)
    }
}

extension VideoPlayerController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer == self.progressPanGestrue {
            let pos = touch.location(in: progressBackgroundBar)
            return progressBackgroundBar.shouldReceivePanGesture(with: pos)
        }
        return true
    }
}

extension VideoPlayerController {
    @objc func handleTapGestureRecognizer(_ gestureRecognizer: UITapGestureRecognizer) {
        self.adjustVideoPlayerStatus()
    }
}

extension VideoPlayerController: VideoPlayerProtocol {
    func isPlayerMuted() -> Bool {
        return player.muted
    }

    func setPlayerMute(_ mute: Bool) {
        player.muted = mute
    }

    public func play() {
        isloading = player.bufferingState != .ready
        //DebugLogging.info(.video, "VideoPlayer Inside playFromCurrentTime")
        videoEndKind = .none
        player.playFromCurrentTime()
    }

    public func pause(endKind: VideoEndKind) {
        //DebugLogging.info(.video, "VideoPlayer Inside pause")
        videoEndKind = endKind
        player.pause()
    }

    public func stop(endKind: VideoEndKind) {
        //DebugLogging.info(.video, "VideoPlayer Inside stop")
        callingStop = true
        videoEndKind = endKind
        player.stop()
        callingStop = false
        localTimeElapsed = 0
    }

    public func endPlay(endKind: VideoEndKind) {
        //DebugLogging.info(.video, "VideoPlayer Inside stop")
        videoEndKind = endKind
        if player.playbackState == .stopped { return }
        callingStop = true
        player.stop()
        player.view.removeFromSuperview()
        videoPlayingTimer?.invalidate()
        isPlaying = false
        self.setProgress(0)
        self.progressBackgroundBar.removeFromSuperview()
        self.delegate = nil
        callingStop = false
        localTimeElapsed = 0
        if endKind == .stopLoadingCache {
            self.player.url = URL(string: VideoPlayerController.urlToStopLoading)
        }
    }

    public func isPlaying(urlString: String) -> Bool {
        return player.url?.absoluteString == urlString
    }

    public func seek(to time: CMTime, completionHandler: ((Bool) -> Void)?) {
        isLoadSuccess = false
        player.seek(to: time, completionHandler: completionHandler)
    }

    public func play(with info: PlayInfo,
                     actionHandler: ActionHandling?,
                     delegate: VideoPlayerDelegate) {

        //DebugLogging.info(.video, "VideoPlayer Inside play")
        if player.url?.absoluteString != info.url.absoluteString {
            url = info.url
            player.url = url
            localTimeElapsed = 0
            isLoadSuccess = false
        }
        shouldSendVideoLog = true
        videoEndKind = .none
        consumptionTimeStart = nil
        videoStartToload = Date()
        self.delegate = delegate
        self.actionHandler = actionHandler
        enableLogging = info.enableLogging
        player.playbackLoops = info.playLoops
        playStyle = info.playStyle
        player.muted = info.isMute
        self.tapGestureRecognizer?.isEnabled = !info.disableGesture
        self.progressPanGestrue.isEnabled = !info.disableGesture

        self.setProgress(0)
        self.playImageView.isHidden = true
    }

    public func update(fillMode: AVLayerVideoGravity) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        player.fillMode = fillMode
        CATransaction.commit()
    }

    public func preload(with url: URL) {
        shouldSendVideoLog = false
        self.url = url
        player.url = url
        self.setProgress(0)
        isloading = true
        isLoadSuccess = false
        player.stop()
    }

    public func getPlayerView() -> UIView {
        return self.player.view
    }

    private func _playerStateDidChange(_ player: Player) {
        let videoLoadDuration = Double(player.maximumDuration)
        var actionKey = VideoLogActionKey.videoFailed.rawValue

        switch player.playbackState {
        case .playing:
            isLoadSuccess = true
            consumptionTimeStart = Date()
            actionKey = VideoLogActionKey.videoPlay.rawValue

            if let videoStartToload = videoStartToload,
               self.shouldSendVideoLog {
                self.videoStartToload = nil
                localLoadingTimeElapsed = Int(ceil(Date().timeIntervalSince(videoStartToload) * 1000))
                
            }

            break
        case .paused:
            guard callingStop == false && videoLoadDuration > 0 else { return }
            isPlaying = false
            videoPlayingTimer?.invalidate()
            playImageView.isHidden = self.isSeeking
            actionKey = VideoLogActionKey.videoPaused.rawValue
            break

        case .stopped:
            guard videoLoadDuration > 0 else { return }
            isPlaying = false
            videoPlayingTimer?.invalidate()
            self.setProgress(0)
            actionKey = VideoLogActionKey.videoEnd.rawValue
            if videoEndKind == .prepareForReuse { return }
            break

        case .failed:
            isLoadSuccess = false
            actionKey = VideoLogActionKey.videoFailed.rawValue
        }

        guard self.shouldSendVideoLog else { return }

        self.delegate?.playerPlaybackStateDidChange(player)

        if player.playbackState != .playing {
            consumptionTimeStart = nil
        }
    }
}

extension VideoPlayerController: PlayerDelegate {
    public func playerReady(_ player: Player) {
        self.delegate?.playerReady(player)
    }

    public func playerPlaybackStateDidChange(_ player: Player) {
        if player.playbackState != .playing {
            _playerStateDidChange(player)
        }
    }

    public func playerBufferingStateDidChange(_ player: Player) {
        if player.bufferingState == .ready {
            isLoadSuccess = true
        }
    }

    public func playerBufferTimeDidChange(_ bufferTime: Double) {
        self.delegate?.playerBufferTimeDidChange(bufferTime)
    }

    public func player(_ player: Player, didFailWithError error: Error?) {
        self.delegate?.player(player, didFailWithError: error)
    }
}

extension VideoPlayerController: PlayerPlaybackDelegate {
    public func playerCurrentTimeDidChange(_ player: Player) {
        if player.currentTimeInterval > 0 {
            self.configDisplay(true)
        }
        if !isDragging && !isSeeking && player.playbackState == .playing && player.maximumDuration > 0 {
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
                guard let self = self else { return }
                self.delegate?.playerTimePassed60sAfterPlay(self.player)
                self.consumptionTimeStart = Date()
            })
        }
        self.delegate?.playerCurrentTimeDidChange(player)
    }

    public func playerPlaybackWillStartFromBeginning(_ player: Player) {

    }

    public func playerPlaybackDidEnd(_ player: Player) {

    }

    public func playerPlaybackWillLoop(_ player: Player) {
        localProgress = 1.0
        
        self.delegate?.playerPlaybackWillLoop(player)

    }

    public func playerPlaybackDidLoop(_ player: Player) {
       
        self.delegate?.playerPlaybackDidLoop(player)
    }
}
