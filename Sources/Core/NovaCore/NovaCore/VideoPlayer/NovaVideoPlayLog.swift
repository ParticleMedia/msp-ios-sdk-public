import Foundation

enum NovaVideoLogActionKey: String {
    case videoPlay      = "log_videoPlay"
    case videoPlaying   = "log_videoPlaying"
    case videoEnd       = "log_video_End"
    case videoPaused    = "log_video_Paused"
    case videoFailed    = "log_videoFailed"
    case videoLoadTime  = "log_video_load_time"
}

struct NovaVideoLogActionDataModel {
    let docid: String
    let timeElapsed: Int
    let timeElapsedFloat: CGFloat
    let progress: CGFloat
    let duration: Int
    let videoLoadDuration: Int
    let source: String
    let isLoadSuccess: Bool
    let meta: String
    let loadingTime: Int
    let playStyle: NovaVideoPlayStyle
    let reason: String

    init(docid: String,
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
