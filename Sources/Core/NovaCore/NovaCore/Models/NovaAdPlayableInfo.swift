//
//  NovaAdPlayableInfo.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/4/15.
//

/// Area to the playable web view after clicking
import Foundation

enum AdPlayableArea: String, Codable {
    case all = "ALL"
    case media = "MEDIA"
}

class NovaAdPlayableInfo: Codable {
    enum Layout: String, Codable {
        case showMedia
        case showPlayable
        case twoPart  // TODO: lsy, two part not work in msp native ad
    }

    enum ActionBarFormat: String, Codable {
        case disable
        case bottom = "BOTTOM"
    }

    enum TapToTryFormat: String, Codable {
        case `default`
        case gamepadWithText = "GAMEPAD_WITH_TEXT"
        case pill = "GAMEPAD_PILL_VIEW"
        case circle = "GAMEPAD_DARK_CIRCLE"
    }

    let playableUrl: URL
    let playableArea: AdPlayableArea
    let layout: Layout
    let actionBarFormat: ActionBarFormat
    let tapToTryFormat: TapToTryFormat

    init(
        playableUrl: URL,
        playableArea: AdPlayableArea,
        layout: Layout,
        actionBarFormat: ActionBarFormat = .disable,
        tapToTryFormat: TapToTryFormat = .default
    ) {
        self.playableUrl = playableUrl
        self.playableArea = playableArea
        self.layout = layout
        self.actionBarFormat = actionBarFormat
        self.tapToTryFormat = tapToTryFormat
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.playableUrl = try container.decode(URL.self, forKey: .playableUrl)
        self.playableArea = try container.decode(AdPlayableArea.self, forKey: .playableArea)
        self.layout = try container.decode(Layout.self, forKey: .layout)
        self.actionBarFormat = try container.decode(ActionBarFormat.self, forKey: .actionBarFormat)
        if let formatString = try? container.decodeIfPresent(String.self, forKey: .tapToTryFormat),
            let format = TapToTryFormat(rawValue: formatString)
        {
            self.tapToTryFormat = format
        } else {
            self.tapToTryFormat = .default
        }
    }

    enum CodingKeys: String, CodingKey {
        case playableUrl
        case playableArea
        case layout
        case actionBarFormat
        case tapToTryFormat
    }
}
