//
//  AdCtrType.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/4/15.
//

import Foundation

struct OpenWebModel: Codable {
    let url: URL
    let openBrowser: Bool
    
    init(url: URL, openBrowser: Bool) {
        self.url = url
        self.openBrowser = openBrowser
    }
}

struct AppInstallModel: Codable {
    let storeId: Int
    // If app store can not be opened, fallback to open web
    let fallbackWebModel: OpenWebModel
    
    init(storeId: Int, fallbackWebModel: OpenWebModel) {
        self.storeId = storeId
        self.fallbackWebModel = fallbackWebModel
    }
}

class PlayableModel: Codable {
    let playableUrl: URL
    let launchAdType: AdCtrType
    let playableArea: AdPlayableArea

    var hasBeenPlayed: Bool = false

    init(playableUrl: URL, fallback: AdCtrType, playableArea: AdPlayableArea) {
        self.playableUrl = playableUrl
        self.launchAdType = fallback
        self.playableArea = playableArea
    }
}

indirect enum AdCtrType: Codable {
    case openWeb(model: OpenWebModel)
    case appInstall(model: AppInstallModel)
    case playable(model: PlayableModel)

    var url: URL {
        switch self {
        case .openWeb(let model):
            return model.url
        case .appInstall(let model):
            return model.fallbackWebModel.url
        case .playable(let model):
            return model.playableUrl
        }
    }
    
    // TODO: - GPY Add additional properties or functionality as needed
    var appStoreId: String? {
        switch self {
        case .openWeb: return nil
        case .appInstall(let model):
            return "\(model.storeId)"
        case .playable(let model):
            return model.launchAdType.appStoreId
        }
    }
    
    var launchOption: NovaAdLaunchOption {
        switch self {
        case .openWeb(let model):
            return model.openBrowser ? .launchBrowser: .launchWebView
        case .appInstall(let model):
            return model.fallbackWebModel.openBrowser ? .launchBrowser : .launchWebView
        case .playable(let model):
            return model.launchAdType.launchOption
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case openWebModel
        case appInstallModel
        case playableModel
    }

    private enum CaseType: String, Codable {
        case openWeb
        case appInstall
        case playable
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .openWeb(let model):
            try container.encode(CaseType.openWeb, forKey: .type)
            try container.encode(model, forKey: .openWebModel)

        case .appInstall(let model):
            try container.encode(CaseType.appInstall, forKey: .type)
            try container.encode(model, forKey: .appInstallModel)

        case .playable(let model):
            try container.encode(CaseType.playable, forKey: .type)
            try container.encode(model, forKey: .playableModel)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(CaseType.self, forKey: .type)

        switch type {
        case .openWeb:
            let model = try container.decode(OpenWebModel.self, forKey: .openWebModel)
            self = .openWeb(model: model)

        case .appInstall:
            let model = try container.decode(AppInstallModel.self, forKey: .appInstallModel)
            self = .appInstall(model: model)

        case .playable:
            let model = try container.decode(PlayableModel.self, forKey: .playableModel)
            self = .playable(model: model)
        }
    }
} 
