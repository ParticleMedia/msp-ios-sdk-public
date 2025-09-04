//
//  NovaAdDiscountTagInfo.swift
//  NovaCore
//
//  Created by Shanyu Li on 2024/12/24.
//

import Foundation

enum NovaAdDiscountTagInfoError: LocalizedError {
    case invalidTagTextStyle(String)
    case incorrectTextStyleParameters(textType: NovaAdDiscountTagStyle.TextType, parametersCount: Int)

    var errorDescription: String? {
        switch self {
        case .invalidTagTextStyle:
            return "The tag text style is invalid."
        case let .incorrectTextStyleParameters(textType, parametersCount):
            return "The text style '\(textType.rawValue)' requires a different number of parameters than provided (\(parametersCount))."
        }
    }
}

struct NovaAdDiscountTagStyle {
    enum TextType: String {
        case priceOff      = "PRICE_OFF"
        case priceSales    = "PRICE_SALES"
    }

    enum Text {
        case priceOff(percentageText: String)
        case priceSales(newPrice: String, originalPrice: String)
    }

    enum Background: String {
        case `default`     = "DEFAULT"
        case red           = "RED"
        case redEmblem     = "RED_EMBLEM"
    }

    let text: Text
    let background: Background
}

struct NovaAdDiscountTagInfo {
    enum Position: String {
        case topLeft       = "TOP_LEFT"
        case topRight      = "TOP_RIGHT"
        case bottomLeft    = "BOTTOM_LEFT"
        case bottomRight   = "BOTTOM_RIGHT"
    }

    let position: Position
    let style: NovaAdDiscountTagStyle

    init(from tagItem: TagItem, backgroundStyle: NovaAdDiscountTagStyle.Background) throws {
        guard let textStyleType = NovaAdDiscountTagStyle.TextType(rawValue: tagItem.style) else {
            throw NovaAdDiscountTagInfoError.invalidTagTextStyle(tagItem.style)
        }

        let textStyle: NovaAdDiscountTagStyle.Text = try {
            switch textStyleType {
            case .priceOff:
                guard tagItem.texts.count == 1 else {
                    throw NovaAdDiscountTagInfoError
                        .incorrectTextStyleParameters(textType: textStyleType, parametersCount: tagItem.texts.count)
                }
                return .priceOff(percentageText: tagItem.texts.first!)
            case .priceSales:
                guard tagItem.texts.count == 2 else {
                    throw NovaAdDiscountTagInfoError
                        .incorrectTextStyleParameters(textType: textStyleType, parametersCount: tagItem.texts.count)
                }
                return .priceSales(newPrice: tagItem.texts[0], originalPrice: tagItem.texts[1])
            }
        }()
        style = NovaAdDiscountTagStyle(text: textStyle, background: backgroundStyle)
        position = Position(rawValue: tagItem.position) ?? .topLeft
    }

    func convertToTagItem() -> TagItem {
        return {
            switch style.text {
            case let .priceOff(percentageText: text):
                TagItem(
                    position: position.rawValue,
                    style: NovaAdDiscountTagStyle.TextType.priceOff.rawValue,
                    texts: [text]
                )
            case let .priceSales(newPrice: newPrice, originalPrice: originalPrice):
                TagItem(
                    position: position.rawValue,
                    style: NovaAdDiscountTagStyle.TextType.priceSales.rawValue,
                    texts: [newPrice, originalPrice]
                )
            }
        }()
    }
}

extension NovaAdDiscountTagInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case tagItem
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let tagItem = try container.decode(TagItem.self, forKey: .tagItem)
        try self.init(from: tagItem, backgroundStyle: .default)
    }

    func encode(to encoder: any Encoder) throws {
        let tagItem = convertToTagItem()
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tagItem, forKey: .tagItem)
    }
} 
