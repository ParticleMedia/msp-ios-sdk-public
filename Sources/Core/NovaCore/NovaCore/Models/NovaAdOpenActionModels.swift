//
//  NovaAdOpenActionModels.swift
//  NovaCore
//
//  Created by Patrick on 2025/1/27.
//

// MARK: - NovaAdOpenActionKey

import Foundation

enum NovaAdOpenActionKey: String {
    case launchBrowser = "launchBrowser"
    case launchWebView = "launchWebView"
    case launchStore = "launchStore"
}

// MARK: - NovaAdOpenActionDataModel

struct NovaAdOpenActionDataModel {
    let url: URL
    let clickTime: CFTimeInterval
    let ad: NovaInterstitialAdItem

    init(url: URL, clickTime: CFTimeInterval, ad: NovaInterstitialAdItem) {
        self.url = url
        self.clickTime = clickTime
        self.ad = ad
    }
}
