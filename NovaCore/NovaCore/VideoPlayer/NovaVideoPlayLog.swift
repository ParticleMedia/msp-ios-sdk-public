import Foundation

public enum NovaVideoLogActionKey: String {
    case videoPlay      = "log_videoPlay"
    case videoPlaying   = "log_videoPlaying"
    case videoEnd       = "log_video_End"
    case videoPaused    = "log_video_Paused"
    case videoFailed    = "log_videoFailed"
    case videoLoadTime  = "log_video_load_time"
}

public struct NovaVideoLogActionDataModel {
    public let docid: String
    public let timeElapsed: Int
    public let timeElapsedFloat: CGFloat
    public let progress: CGFloat
    public let duration: Int
    public let videoLoadDuration: Int
    public let source: String
    public let isLoadSuccess: Bool
    public let meta: String
    public let loadingTime: Int
    public let playStyle: NovaVideoPlayStyle
    public let reason: String

    public init(docid: String,
                timeElapsed: Int,
                timeElapsedFloat: CGFloat,
                progress: CGFloat,
                duration: Int,
                videoLoadDuration: Int,
                source: String,
                isLoadSuccess: Bool,
                meta: String,
                loadingTime: Int,
                playStyle: NovaVideoPlayStyle,
                reason: String) {
        self.docid = docid
        self.timeElapsed = timeElapsed
        self.timeElapsedFloat = timeElapsedFloat
        self.progress = progress
        self.duration = duration
        self.videoLoadDuration = videoLoadDuration
        self.source = source
        self.isLoadSuccess = isLoadSuccess
        self.meta = meta
        self.loadingTime = loadingTime
        self.playStyle = playStyle
        self.reason = reason
    }
}
