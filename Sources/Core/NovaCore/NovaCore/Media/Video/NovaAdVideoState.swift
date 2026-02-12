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

    private(set) var playState: PlayState
    private(set) var isMute: Bool
    private(set) var loopCount: Int = 0

    // MARK: - Mutating Updates

    mutating func transition(to playState: PlayState) {
        self.playState = playState
    }

    mutating func updatePlayingTime(currentTime: CMTime, videoLength: TimeInterval) {
        guard case .playing = playState else { return }
        playState = .playing(currentTime: currentTime, videoLength: videoLength)
    }

    mutating func updatePausedTime(currentTime: CMTime, videoLength: TimeInterval) {
        guard case .paused(_, _, let endKind) = playState else { return }
        playState = .paused(currentTime: currentTime, videoLength: videoLength, endKind: endKind)
    }

    mutating func updateMuteState(_ isMute: Bool) {
        self.isMute = isMute
    }

    mutating func updateLoopCount(_ count: Int) {
        self.loopCount = count
    }
}
