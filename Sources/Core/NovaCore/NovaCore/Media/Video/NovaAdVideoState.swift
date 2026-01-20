import CoreMedia

struct NovaAdVideoState {

    enum PlayState: Equatable {
        case showCover(autoPlay: Bool, coverURL: URL)
        case loading
        case playing(currentTime: CMTime, videoLength: TimeInterval)
        case paused(currentTime: CMTime, videoLength: TimeInterval, endKind: NovaVideoEndKind)
        case endPlaying(shouldShowPlayButton: Bool)
    }

    init(playState: PlayState, isMute: Bool) {
        self.playState = playState
        self.isMute = isMute
    }

    var playState: PlayState
    var isMute: Bool
    var loopCount: Int = 0
}
