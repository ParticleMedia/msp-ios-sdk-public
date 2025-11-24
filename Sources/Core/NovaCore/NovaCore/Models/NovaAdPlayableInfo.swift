//
//  NovaAdPlayableInfo.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/4/15.
//

import Foundation

/// Area to the playable web view after clicking
enum AdPlayableArea: String, Codable{
    case all    = "ALL"
    case media  = "MEDIA"
}

class NovaAdPlayableInfo: Codable {

    enum Layout: String, Codable {
        case showMedia
        case showPlayable
        case twoPart // TODO: lsy, two part not work in msp native ad
    }

    let playableUrl: URL
    let playableArea: AdPlayableArea
    let layout: Layout

    init(
        playableUrl: URL,
        playableArea: AdPlayableArea,
        layout: Layout
    ) {
        self.playableUrl = playableUrl
        self.playableArea = playableArea
        self.layout = layout
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.playableUrl = try container.decode(URL.self, forKey: .playableUrl)
        self.playableArea = try container.decode(AdPlayableArea.self, forKey: .playableArea)
        self.layout = try container.decode(Layout.self, forKey: .layout)
    }
} 
