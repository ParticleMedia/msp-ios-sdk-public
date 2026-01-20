//
//  NovaBaseAd+Log.swift
//  NovaCore
//
//  Created by Pengyu Gou on 2025/11/12.
//

import Foundation

extension NovaBaseAd {
    public func logAdHide(reason: String) {
        NovaAdMetricReporter.logAdHide(reason: reason, encryptedAdToken: encryptedAdToken)
    }
}
