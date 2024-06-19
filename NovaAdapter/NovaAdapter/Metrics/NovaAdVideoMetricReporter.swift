//
//  NovaAdVideoMetricReporter.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 6/18/24.
//

import Foundation

public class NovaAdVideoMetricReporter {

    public struct ProgressPercentagePoint {
        let percentage: Double
        let event: NovaAdEvent
    }

    public struct ProgressDurationPoint {
        let duration: Double
        let event: NovaAdEvent
        let params: [String:String]
    }

    public class LogRecord {

        var didLogStart: Bool = false
        var ratioPoints: [ProgressPercentagePoint] = [
            ProgressPercentagePoint(percentage: 0.25, event: .videoFirstQuartile),
            ProgressPercentagePoint(percentage: 0.50, event: .videoMidPoint),
            ProgressPercentagePoint(percentage: 0.75, event: .videoThirdQuartile),
            ProgressPercentagePoint(percentage: 1.00, event: .videoComplete),
        ]
        var timePoints: [ProgressDurationPoint] = [
            ProgressDurationPoint(duration: 3.0, event: .videoProgess, params: ["offset":"3.0"])
        ]
    }

    private static var allVideoLogRecords = [String: LogRecord]()

    public static func makeRecord(encryptedAdToken: String) {
        if allVideoLogRecords[encryptedAdToken] != nil {
            return
        }
        allVideoLogRecords[encryptedAdToken] = LogRecord()
    }

    public static func logVideoError(encryptedAdToken: String, error: String, duration: Double) {
        let params: [String: String] = [
            "error": error,
            "duration_ms": "\(Int(duration * 1000))",
        ]
        NovaAdMetricReporter.logVideoEvent(.videoError, encryptedAdToken: encryptedAdToken, params: params)
    }

    public static func logVideoStart(encryptedAdToken: String,
                                     isAuto: Bool,
                                     isMute: Bool,
                                     isLoop: Bool,
                                     videoLength: Double,
                                     latency: Double,
                                     duration: Double) {
        guard let record = allVideoLogRecords[encryptedAdToken] else {
            return
        }
        if record.didLogStart {
            return
        }
        record.didLogStart = true
        let params: [String: String] = [
            "is_play_automatically": String(isAuto),
            "is_mute": "\(isMute)",
            "is_loop": "\(isLoop)",
            "video_length_ms": "\(Int(videoLength * 1000))",
            "latency_ms": "\(Int(latency * 1000))",
            "duration_ms": "\(Int(duration * 1000))",
        ]
        NovaAdMetricReporter.logVideoEvent(.videoStart, encryptedAdToken: encryptedAdToken, params: params)
    }

    public static func logVideoProgress(encryptedAdToken: String, percentage: Double, duration: Double) {
        guard let record = allVideoLogRecords[encryptedAdToken] else {
            return
        }

        if let point = record.ratioPoints.first, percentage >= point.percentage {
            record.ratioPoints.removeFirst()
            NovaAdMetricReporter.logVideoEvent(point.event, encryptedAdToken: encryptedAdToken)
        }
        if let point = record.timePoints.first, duration >= point.duration {
            record.timePoints.removeFirst()
            NovaAdMetricReporter.logVideoEvent(point.event, encryptedAdToken: encryptedAdToken, params: point.params)
        }
    }

    public static func logVideoPause(encryptedAdToken: String, duration: Double) {
        let params: [String: String] = [
            "duration_ms": "\(Int(duration * 1000))",
        ]
        NovaAdMetricReporter.logVideoEvent(.videoPause, encryptedAdToken: encryptedAdToken, params: params)
    }

    public static func logVideoResume(encryptedAdToken: String, duration: Double) {
        let params: [String: String] = [
            "duration_ms": "\(Int(duration * 1000))",
        ]
        NovaAdMetricReporter.logVideoEvent(.videoResume, encryptedAdToken: encryptedAdToken, params: params)
    }

    public static func logVideoMute(encryptedAdToken: String, isMute: Bool) {
        NovaAdMetricReporter.logVideoEvent(isMute ? .videoMute : .videoUnMute, encryptedAdToken: encryptedAdToken)
    }
}

