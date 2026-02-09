import Foundation
import QuartzCore

final class NovaAdImpressionTimeTracker {
    private static var impressionTimes: [String: Double] = [:]

    static func trackImpressionTime(encryptedAdToken: String, impressionTime: Double) {
        impressionTimes[encryptedAdToken] = impressionTime
    }

    static func durationParams(encryptedAdToken: String) -> [String: String] {
        guard let impressionTime = impressionTimes[encryptedAdToken] else { return [:] }
        let duration = TimeInterval(CACurrentMediaTime() - impressionTime)
        let durationInMs = duration * 1000
        guard durationInMs.isFinite, !durationInMs.isNaN else { return [:] }
        if durationInMs >= Double(Int64.max) || durationInMs <= Double(Int64.min) {
            return [:]
        }
        return ["duration_ms": "\(Int64(durationInMs))"]
    }

    static func clear(encryptedAdToken: String) {
        impressionTimes.removeValue(forKey: encryptedAdToken)
    }
}
