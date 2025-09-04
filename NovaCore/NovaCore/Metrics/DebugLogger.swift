//
//  DebugLogger.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/7.
//

import OSLog

struct DebugLogger {
    static let DOMAIN = "com.newsbreak.nova"

    static let network = Logger(subsystem: DOMAIN, category: "network")
    static let ui = Logger(subsystem: DOMAIN, category: "ui")
    static let data = Logger(subsystem: DOMAIN, category: "")
}
