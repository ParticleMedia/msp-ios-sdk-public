//
//  Double+Extension.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/6.
//

import Foundation

extension TimeInterval {
    // return optional
    func toMMSSString() -> String? {
        guard let timeInInt = safeToInt() else {
            return nil
        }

        let second = timeInInt % 60
        let minute = timeInInt / 60
        let secondStr = second < 10 ? "0\(second)" : "\(second)"
        let minuteStr = minute < 10 ? "0\(minute)" : "\(minute)"
        return "\(minuteStr):\(secondStr)"
    }

    func safeToInt() -> Int? {
        if self >= Double(Int.min).nextUp, self <= Double(Int.max).nextDown {
            return Int(self)
        } else {
            return nil
        }
    }
    
    func makeFinite() -> Double? {
        if self.isNaN || self.isInfinite {
            return nil
        } else {
            return self
        }
    }
    
    func msString() -> String {
        guard isFinite, !isNaN else { return "0" }
        let ms = self * 1000
        if ms >= Double(Int64.max) { return String(Int64.max) }
        if ms <= Double(Int64.min) { return String(Int64.min) }
        return String(Int64(ms))
    }
}

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}
