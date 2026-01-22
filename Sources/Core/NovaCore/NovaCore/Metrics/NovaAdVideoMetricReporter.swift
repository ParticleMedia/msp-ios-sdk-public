//
//  NovaAdVideoMetricReporter.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 6/18/24.
//

import Foundation
import UIKit

class NovaAdVideoMetricReporter {
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
    }

    private static var allVideoLogRecords: [String: LogRecord] = [:]

    static func makeRecord(encryptedAdToken: String) {
        if allVideoLogRecords[encryptedAdToken] != nil {
            return
        }
        allVideoLogRecords[encryptedAdToken] = LogRecord()
    }

    static func logVideoError(encryptedAdToken: String, error: String, duration: Double) {
        var params: [String: String] = [
            NovaAdMetricKeys.ERROR: error,
            NovaAdMetricKeys.DURATION_MS: duration.msString(),
        ]
        if let durationInMs = (duration * 1000).safeToInt() {
            params["duration_ms"] = "\(durationInMs)"
        }
        NovaAdMetricReporter.logVideoEvent(.videoError, encryptedAdToken: encryptedAdToken, params: params)
    }

    static func logVideoStart(
        encryptedAdToken: String,
        videoInfo: NovaNativeAdVideoInfo?,
        startTime: Double?,
        configTime: Double?,
        novaVideoPlayer: NovaVideoPlayer?
    ) {
        guard let record = allVideoLogRecords[encryptedAdToken] else {
            return
        }

        if record.didLogStart {
            return
        }
        record.didLogStart = true
        let params = NovaAdVideoMetricReporter.getVideoParams(
            videoInfo: videoInfo, startTime: startTime, configTime: configTime, novaVideoPlayer: novaVideoPlayer)
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
            NovaAdMetricReporter.logVideoEvent(
                point.event, encryptedAdToken: encryptedAdToken, params: ["duration_ms": duration.msString()])
        }
        if let point = record.timePoints.first, duration >= point.duration {
            record.timePoints.removeFirst()
            var params: [String: String] = [:]
            for (key, value) in point.params {
                params[key] = value
            }
            params[NovaAdMetricKeys.DURATION_MS] = duration.msString()
            NovaAdMetricReporter.logVideoEvent(point.event, encryptedAdToken: encryptedAdToken, params: params)
        }
    }

    static func logVideoEnd(
        encryptedAdToken: String,
        percentage: Double,
        videoInfo: NovaNativeAdVideoInfo?,
        startTime: Double?,
        configTime: Double?,
        novaVideoPlayer: NovaVideoPlayer?
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
        let params = NovaAdVideoMetricReporter.getVideoParams(
            videoInfo: videoInfo, startTime: startTime, configTime: configTime, novaVideoPlayer: novaVideoPlayer)
        NovaAdMetricReporter.logVideoEvent(.videoComplete, encryptedAdToken: encryptedAdToken, params: params)
    }

    static func logVideoPause(
        encryptedAdToken: String,
        duration: Double,
        reason: NovaAdVideoMetricReporter.NovaAdEventPauseReason?,
        videoInfo: NovaNativeAdVideoInfo?,
        startTime: Double?,
        configTime: Double?,
        novaVideoPlayer: NovaVideoPlayer?
    ) {
        var params = NovaAdVideoMetricReporter.getVideoParams(
            videoInfo: videoInfo, startTime: startTime, configTime: configTime, novaVideoPlayer: novaVideoPlayer,
            duration: duration)
        if let reason {
            params[NovaAdMetricKeys.REASON] = reason.rawValue
        }
        NovaAdMetricReporter.logVideoEvent(.videoPause, encryptedAdToken: encryptedAdToken, params: params)
    }

    static func logVideoResume(
        encryptedAdToken: String,
        duration: Double,
        videoInfo: NovaNativeAdVideoInfo?,
        startTime: Double?,
        configTime: Double?,
        novaVideoPlayer: NovaVideoPlayer?
    ) {
        let params = NovaAdVideoMetricReporter.getVideoParams(
            videoInfo: videoInfo, startTime: startTime, configTime: configTime, novaVideoPlayer: novaVideoPlayer,
            duration: duration)
        NovaAdMetricReporter.logVideoEvent(.videoResume, encryptedAdToken: encryptedAdToken, params: params)
    }

    static func logVideoMute(encryptedAdToken: String, isMute: Bool) {
        NovaAdMetricReporter.logVideoEvent(isMute ? .videoMute : .videoUnMute, encryptedAdToken: encryptedAdToken)
    }

    private static func getVideoParams(
        videoInfo: NovaNativeAdVideoInfo?,
        startTime: Double?,
        configTime: Double?,
        novaVideoPlayer: NovaVideoPlayer?,
        duration: Double? = nil
    ) -> [String: String] {
        var params: [String: String] = [:]
        let currentTime = CACurrentMediaTime()
        if let duration = duration {
            params[NovaAdMetricKeys.DURATION_MS] = duration.msString()
        } else if let configTime = configTime {
            let duration = currentTime - configTime
            params[NovaAdMetricKeys.DURATION_MS] = duration.msString()
        }
        if let startTime = startTime {
            let latency = currentTime - startTime
            params[NovaAdMetricKeys.LATENCY_MS] = latency.msString()
        }
        if let videoInfo = videoInfo {
            params[NovaAdMetricKeys.IS_PLAY_AUTOMATICALLY] = String(videoInfo.isAuto)
            params[NovaAdMetricKeys.IS_MUTE] = String(videoInfo.isMute)
            params[NovaAdMetricKeys.IS_LOOP] = String(videoInfo.isLoop)
        }
        if let novaVideoPlayer = novaVideoPlayer {
            let player = novaVideoPlayer.player
            let videoLength = player.maximumDuration
            params[NovaAdMetricKeys.VIDEO_LENGTH_MS] = videoLength.msString()
            params[NovaAdMetricKeys.POSITION_MS] = videoLength.msString()
            params[NovaAdMetricKeys.LOOP_COUNT] = String(player.loopCount)
        }
        return params
    }
}
