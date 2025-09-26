//
//  LottieAsset.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/9/26.
//

import Foundation

class LottieAsset {
    static var bundle: Bundle? {
        if let path = Bundle(for: LottieAsset.self).path(forResource: "NBResourceBundle", ofType: "bundle") {
            return Bundle(path: path)
        } else {
            return nil
        }
    }

    static func getAssetURL(_ name: String) -> URL? {
        return bundle?.url(forResource: name, withExtension: "json", subdirectory: "Lottie")
    }
}
