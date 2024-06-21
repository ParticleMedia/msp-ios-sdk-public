import AVFoundation

public enum VideoPlayStyle: String {
    case none = "none"
    case feed = "feed"
    case immersiveFeed = "immersive_feed"
    case previewFeed = "preview_feed"
    case adInFeed = "ad_in_feed"
}

public struct PlayInfo {
    let url: URL
    let playLoops: Bool
    let videoDataModel: Any?
    let playStyle: VideoPlayStyle
    let isMute: Bool
    let disableGesture: Bool
    let enableLogging: Bool

    public init(url: URL,
                playLoops: Bool,
                videoDataModel: Any?,
                playStyle: VideoPlayStyle,
                isMute: Bool,
                disableGesture: Bool,
                enableLogging: Bool = true) {
        self.url = url
        self.playLoops = playLoops
        self.videoDataModel = videoDataModel
        self.playStyle = playStyle
        self.isMute = isMute
        self.disableGesture = disableGesture
        self.enableLogging = enableLogging
    }
}

public protocol VideoPlayerDelegate: NSObjectProtocol {
    func playerReady(_ player: Player)
    func playerPlaybackStateDidChange(_ player: Player)
    func playerBufferTimeDidChange(_ bufferTime: Double)
    func playerCurrentTimeDidChange(_ player: Player)
    func playerTimePassed60sAfterPlay(_ player: Player)
    func player(_ player: Player, didFailWithError error: Error?)
    func playerPlaybackWillLoop(_ player: Player)
    func playerPlaybackDidLoop(_ player: Player)
}

protocol VideoPlayerProtocol {
    func play()
    func pause(endKind: VideoEndKind)
    func endPlay(endKind: VideoEndKind)
    func seek(to time: CMTime,
              completionHandler: ((Bool) -> Swift.Void)?)
    func play(with info: PlayInfo,
              actionHandler: ActionHandling?,
              delegate: VideoPlayerDelegate)
    func isPlayerMuted() -> Bool
    func setPlayerMute(_ mute: Bool)
}

