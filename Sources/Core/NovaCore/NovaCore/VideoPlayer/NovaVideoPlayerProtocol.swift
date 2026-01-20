import AVFoundation

enum NovaVideoPlayStyle: String {
    case none = "none"
    case feed = "feed"
    case immersiveFeed = "immersive_feed"
    case previewFeed = "preview_feed"
    case adInFeed = "ad_in_feed"
}

struct NovaPlayInfo {
    let url: URL
    let playLoops: Bool
    let videoDataModel: Any?
    let playStyle: NovaVideoPlayStyle
    let isMute: Bool
    let disableGesture: Bool
    let enableLogging: Bool

    init(url: URL,
         playLoops: Bool,
         videoDataModel: Any?,
         playStyle: NovaVideoPlayStyle,
         isMute: Bool,
         disableGesture: Bool,
         enableLogging: Bool = true)
    {
        self.url = url
        self.playLoops = playLoops
        self.videoDataModel = videoDataModel
        self.playStyle = playStyle
        self.isMute = isMute
        self.disableGesture = disableGesture
        self.enableLogging = enableLogging
    }
}

protocol NovaVideoPlayerDelegate: NSObjectProtocol {
    func playerReady(_ player: NovaPlayer)
    func playerPlaybackStateDidChange(_ player: NovaPlayer)
    func playerBufferTimeDidChange(_ bufferTime: Double)
    func playerCurrentTimeDidChange(_ player: NovaPlayer)
    func playerTimePassed60sAfterPlay(_ player: NovaPlayer)
    func player(_ player: NovaPlayer, didFailWithError error: Error?)
    func playerPlaybackWillLoop(_ player: NovaPlayer)
    func playerPlaybackDidLoop(_ player: NovaPlayer)
    func playerDidPlayToEndTime(_ player: NovaPlayer)
}

protocol NovaVideoPlayerProtocol {
    func play()
    func pause(endKind: NovaVideoEndKind)
    func endPlay(endKind: NovaVideoEndKind)
    func seek(to time: CMTime,
              completionHandler: ((Bool) -> Swift.Void)?)
    func play(with info: NovaPlayInfo,
              actionHandler: ActionHandling?,
              delegate: NovaVideoPlayerDelegate)
    func isPlayerMuted() -> Bool
    func setPlayerMute(_ mute: Bool)
}

