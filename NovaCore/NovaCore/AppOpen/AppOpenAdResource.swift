//
//  AppOpenAdResource.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/2/24.
//

import Foundation
import UIKit

public class AppOpenAdResource {
    static func bundle() -> Bundle? {
        let path = (Bundle(for: AppOpenAdResource.self).resourcePath! as NSString).appendingPathComponent("AppOpenAdResource.bundle")
        let bundle = Bundle(path: path)
        return bundle
    }

    static func image(_ id: String) -> UIImage {
        var image = UIImage()
        if let bundle = self.bundle() {
            image = UIImage(named: id, in: bundle, compatibleWith: nil)!
        }
        return image
    }
}
