//
//  NovaAdMedia.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/7.
//

import Foundation

// MARK: - NovaAdMediaError

enum NovaAdMediaError: LocalizedError {
    case creativeTypeMissing(adId: String)
    case invalid(adId: String, creativeType: NovaCreativeType, message: String?)

    var errorDescription: String? {
        switch self {
        case .creativeTypeMissing(let adId):
            return "Creative type is missing for ad with ID: \(adId)"
        case .invalid(let adId, let creativeType, let message):
            if let message = message {
                return "Invalid media for ad with ID: \(adId), Creative Type: \(creativeType). Details: \(message)"
            } else {
                return "Invalid media for ad with ID: \(adId), Creative Type: \(creativeType)."
            }
        }
    }
}

// MARK: - NovaAdMedia

enum NovaAdMedia {
    case image(model: NovaAdImageMediaModel)
    case video(model: NovaAdVideoMediaModel)
    case multipleImages(model: NovaAdMultipleImagesMediaModel)
    case multipleItems(model: NovaAdMultipleItemsMediaModel)
    case imagePlayable(imageModel: NovaAdImageMediaModel, playableModel: NovaAdPlayableMediaModel)
    case videoPlayable(videoModel: NovaAdVideoMediaModel, playableModel: NovaAdPlayableMediaModel)
}

// MARK: - NovaAdMediaType
// For public use
public enum NovaAdMediaType {
    case image
    case video
    case multipleImages
    case multipleItems
    case playable
}
