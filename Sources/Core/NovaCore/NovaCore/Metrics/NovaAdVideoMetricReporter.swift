import Foundation
import QuartzCore

class NovaAdVideoMetricReporter {
    private static func msInt(_ value: Double) -> Int? {
        guard value.isFinite, !value.isNaN else { return nil }
        let ms = value * 1000
        if ms >= Double(Int.max) || ms <= Double(Int.min) {
            return nil
        }
        return Int(ms)
    }

    enum NovaAdEventPauseReason: String {
        case manual
        case auto
    }

    struct ProgressPercentagePoint {
        let percentage: Double
        let event: NovaAdEvent
    }

    struct ProgressDurationPoint {
        let duration: Double
        let event: NovaAdEvent
        let params: [String: String]
    }

    class LogRecord {
        var didLogStart: Bool = false
        var didLogEnd: Bool = false
        var ratioPoints: [ProgressPercentagePoint] = [
            ProgressPercentagePoint(percentage: 0.25, event: .videoFirstQuartile),
            ProgressPercentagePoint(percentage: 0.50, event: .videoMidPoint),
            ProgressPercentagePoint(percentage: 0.75, event: .videoThirdQuartile),
        ]
        var timePoints: [ProgressDurationPoint] = [
            ProgressDurationPoint(duration: 3.0, event: .videoProgress, params: [NovaAdMetricKeys.OFFSET: "3.0"])
        ]
        var cumulativeMediaTime: Double = 0
        var lastPositionTime: Double?
        var lastMediaSampleTime: Double?
    }

    private static var allVideoLogRecords: [String: LogRecord] = [:]

    static func makeRecord(encryptedAdToken: String) {
        if allVideoLogRecords[encryptedAdToken] != nil {
            return
        }
        allVideoLogRecords[encryptedAdToken] = LogRecord()
    }

    static func logVideoError(encryptedAdToken: String, error: String) {
        var params: [String: String] = [
            NovaAdMetricKeys.ERROR: error
        ]
        params.merge(NovaAdImpressionTimeTracker.durationParams(encryptedAdToken: encryptedAdToken)) {
            current, _ in current
        }
        NovaAdMetricReporter.logVideoEvent(.videoError, encryptedAdToken: encryptedAdToken, params: params)
    }

    static func logVideoStart(
        encryptedAdToken: String,
        isAuto: Bool,
        isMute: Bool,
        isLoop: Bool,
        isVideoClickable: Bool,
        videoLength: Double,
        latency: Double?
    ) {
        guard let record = allVideoLogRecords[encryptedAdToken] else {
            return
        }

        if record.didLogStart {
            return
        }
        record.didLogStart = true

        var params: [String: String] = [
            NovaAdMetricKeys.IS_PLAY_AUTOMATICALLY: "\(isAuto)",
            NovaAdMetricKeys.IS_MUTE: "\(isMute)",
            NovaAdMetricKeys.IS_LOOP: "\(isLoop)",
            NovaAdMetricKeys.IS_VIDEO_CLICKABLE: "\(isVideoClickable)",
        ]
        if let videoLengthInMs = msInt(videoLength) {
            params[NovaAdMetricKeys.VIDEO_LENGTH_MS] = "\(videoLengthInMs)"
        }
        if let latency, let latencyInMs = msInt(latency) {
            params[NovaAdMetricKeys.LATENCY_MS] = "\(latencyInMs)"
        }
        params.merge(NovaAdImpressionTimeTracker.durationParams(encryptedAdToken: encryptedAdToken)) {
            current, _ in current
        }
        NovaAdMetricReporter.logVideoEvent(.videoStart, encryptedAdToken: encryptedAdToken, params: params)
    }

    static func logVideoProgress(
        encryptedAdToken: String,
        percentage: Double,
        duration: Double
    ) {
        guard let record = allVideoLogRecords[encryptedAdToken] else {
            return
        }

        if let point = record.ratioPoints.first, percentage >= point.percentage {
            record.ratioPoints.removeFirst()
            let params = NovaAdImpressionTimeTracker.durationParams(encryptedAdToken: encryptedAdToken)
            NovaAdMetricReporter.logVideoEvent(point.event, encryptedAdToken: encryptedAdToken, params: params)
        }
        if let point = record.timePoints.first, duration >= point.duration {
            record.timePoints.removeFirst()
            var params = point.params
            let durationParam = NovaAdImpressionTimeTracker.durationParams(encryptedAdToken: encryptedAdToken)
            params.merge(durationParam) { current, _ in current }
            NovaAdMetricReporter.logVideoEvent(point.event, encryptedAdToken: encryptedAdToken, params: params)
        }
    }

    static func logVideoEnd(
        encryptedAdToken: String,
        percentage: Double
    ) {
        guard let record = allVideoLogRecords[encryptedAdToken] else {
            return
        }

        guard !record.didLogEnd else {
            return
        }

        guard percentage >= 1.0 else {
            return
        }

        record.didLogEnd = true
        let params = NovaAdImpressionTimeTracker.durationParams(encryptedAdToken: encryptedAdToken)
        NovaAdMetricReporter.logVideoEvent(.videoComplete, encryptedAdToken: encryptedAdToken, params: params)
    }

    static func logVideoPause(
        encryptedAdToken: String,
        reason: NovaAdEventPauseReason?,
        loopCount: Int,
        positionTime: Double?,
        videoLength: Double?
    ) {
        let record = allVideoLogRecords[encryptedAdToken]

        if let positionTime {
            record?.lastPositionTime = positionTime
        }

        var params: [String: String] = [
            NovaAdMetricKeys.LOOP_COUNT: String(loopCount)
        ]
        params.merge(NovaAdImpressionTimeTracker.durationParams(encryptedAdToken: encryptedAdToken)) {
            current, _ in current
        }
        if let videoLength, let videoLengthInMs = msInt(videoLength) {
            params[NovaAdMetricKeys.VIDEO_LENGTH_MS] = "\(videoLengthInMs)"
        }
        if let reason {
            params[NovaAdMetricKeys.REASON] = reason.rawValue
        }
        if let positionTime, let positionTimeInMs = msInt(positionTime) {
            params[NovaAdMetricKeys.POSITION_MS] = "\(positionTimeInMs)"
        }
        if let totalWatchTimeInMs = msInt(record?.cumulativeMediaTime ?? 0) {
            params[NovaAdMetricKeys.TOTAL_WATCH_TIME_MS] = "\(totalWatchTimeInMs)"
        }
        NovaAdMetricReporter.logVideoEvent(.videoPause, encryptedAdToken: encryptedAdToken, params: params)
    }

    static func logVideoResume(
        encryptedAdToken: String,
        reason: NovaAdEventPauseReason
    ) {
        var params: [String: String] = [
            NovaAdMetricKeys.REASON: reason.rawValue
        ]
        params.merge(NovaAdImpressionTimeTracker.durationParams(encryptedAdToken: encryptedAdToken)) {
            current, _ in current
        }
        NovaAdMetricReporter.logVideoEvent(.videoResume, encryptedAdToken: encryptedAdToken, params: params)
    }

    static func logVideoMute(encryptedAdToken: String, isMute: Bool) {
        let params = NovaAdImpressionTimeTracker.durationParams(encryptedAdToken: encryptedAdToken)
        NovaAdMetricReporter.logVideoEvent(
            isMute ? .videoMute : .videoUnMute, encryptedAdToken: encryptedAdToken, params: params)
    }

    static func trackVideoMediaTime(
        encryptedAdToken: String,
        positionTime: Double,
        videoLength: Double,
        isPlaying: Bool
    ) {
        guard let record = allVideoLogRecords[encryptedAdToken] else {
            return
        }
        if !isPlaying {
            record.lastPositionTime = positionTime
            return
        }
        let now = CACurrentMediaTime()
        if let lastSampleTime = record.lastMediaSampleTime, now - lastSampleTime < 0.2 {
            return
        }
        record.lastMediaSampleTime = now

        let mediaDelta: Double
        if let lastPositionTime = record.lastPositionTime {
            if positionTime >= lastPositionTime {
                mediaDelta = positionTime - lastPositionTime
            } else if videoLength > 0 {
                mediaDelta = max(0, videoLength - lastPositionTime) + positionTime
            } else {
                mediaDelta = 0
            }
        } else {
            mediaDelta = 0
        }

        if mediaDelta > 0 {
            record.cumulativeMediaTime += mediaDelta
        }
        record.lastPositionTime = positionTime
    }

    static func clear(encryptedAdToken: String) {
        allVideoLogRecords.removeValue(forKey: encryptedAdToken)
    }
}
