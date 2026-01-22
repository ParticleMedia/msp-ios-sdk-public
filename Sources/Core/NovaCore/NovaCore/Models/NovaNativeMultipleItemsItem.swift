//
//  NovaNativeMultipleItemsItem.swift
//  NovaCore
//
//  Created by Shanyu Li on 2024/7/16.
//

import Foundation

struct NovaNativeMultipleItemsItem: Codable {
    let imageUrl: URL
    let body: String
    let callToAction: String
    let ctrType: AdCtrType?

    enum CodingKeys: String, CodingKey {
        case imageUrl
        case body
        case callToAction
        case url
        case ctrType
    }

    init(imageUrl: URL, body: String, callToAction: String, ctrType: AdCtrType?) {
        self.imageUrl = imageUrl
        self.body = body
        self.callToAction = callToAction
        self.ctrType = ctrType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let imageUrlString = try container.decode(String.self, forKey: .imageUrl)
        guard let imageUrl = URL(string: imageUrlString) else {
            throw DecodingError.dataCorruptedError(forKey: .imageUrl, in: container, debugDescription: "Invalid URL")
        }
        self.imageUrl = imageUrl

        self.body = try container.decode(String.self, forKey: .body)
        self.callToAction = try container.decode(String.self, forKey: .callToAction)
        self.ctrType = try container.decodeIfPresent(AdCtrType.self, forKey: .ctrType)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(imageUrl.absoluteString, forKey: .imageUrl)
        try container.encode(body, forKey: .body)
        try container.encode(callToAction, forKey: .callToAction)
        try container.encodeIfPresent(ctrType, forKey: .ctrType)
    }
}
