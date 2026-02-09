import Foundation
import QuartzCore

class NovaAdImageMetricReporter {
    private static func msInt(_ value: Double) -> Int? {
        guard value.isFinite, !value.isNaN else { return nil }
        let ms = value * 1000
        if ms >= Double(Int.max) || ms <= Double(Int.min) {
            return nil
        }
        return Int(ms)
    }

    class LogRecord {
        var cumulativeDwellTime: Double = 0
        var lastShowTimestamp: Double?
        var showCount: Int = 0
    }

    private static var allImageLogRecords: [String: LogRecord] = [:]

    static func makeRecord(encryptedAdToken: String) {
        if allImageLogRecords[encryptedAdToken] != nil {
            return
        }
        allImageLogRecords[encryptedAdToken] = LogRecord()
    }

    static func trackImageShowTime(encryptedAdToken: String) {
        guard let record = allImageLogRecords[encryptedAdToken] else {
            return
        }
        record.lastShowTimestamp = CACurrentMediaTime()
        record.showCount += 1
    }

    static func logImageDwell(encryptedAdToken: String) {
        guard let record = allImageLogRecords[encryptedAdToken],
            let lastShowTimestamp = record.lastShowTimestamp
        else {
            return
        }
        let hideTimestamp = CACurrentMediaTime()

        let sessionDwellTime = hideTimestamp - lastShowTimestamp
        guard sessionDwellTime > 0 else {
            record.lastShowTimestamp = nil
            return
        }
        record.cumulativeDwellTime += sessionDwellTime
        record.lastShowTimestamp = nil

        var params: [String: String] = [:]
        params[NovaAdMetricKeys.SHOW_COUNT] = "\(record.showCount)"
        if let sessionDwellTimeInMs = msInt(sessionDwellTime) {
            params[NovaAdMetricKeys.SESSION_DWELL_TIME_MS] = "\(sessionDwellTimeInMs)"
        }
        if let totalDwellTimeInMs = msInt(record.cumulativeDwellTime) {
            params[NovaAdMetricKeys.TOTAL_DWELL_TIME_MS] = "\(totalDwellTimeInMs)"
        }
        params.merge(NovaAdImpressionTimeTracker.durationParams(encryptedAdToken: encryptedAdToken)) {
            current, _ in current
        }
        NovaAdMetricReporter.logImageEvent(.imageDwell, encryptedAdToken: encryptedAdToken, params: params)
    }

    static func clear(encryptedAdToken: String) {
        allImageLogRecords.removeValue(forKey: encryptedAdToken)
    }
}
