import CoreMedia

public struct NovaNativeAdVideoState {

    enum PlayState: Equatable {
        case showCover(autoPlay: Bool)
        case loading(hideCover: Bool)
        case playing(currentTime: CMTime)
        case paused(currentTime: CMTime)
        case complete
    }

    let playState: PlayState
    public let isMute: Bool

    init(playState: PlayState,
         isMute: Bool
    ) {
        self.playState = playState
        self.isMute = isMute
    }
}
