//
//  NovaResource.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/9/26.
//

import Foundation

class NovaResource {
    // MARK: Internal

    static func getLottieResourceURL(_ name: String) -> URL? {
        return getResourceURL(name, withExtension: "json", subdirectory: "Lottie")
    }

    static func getJSScriptResourceURL(_ name: String) -> URL? {
        return getResourceURL(name, withExtension: "js", subdirectory: "Scripts")
    }

    // MARK: Private

    private static var bundle: Bundle? {
        if let path = Bundle(for: NovaResource.self).path(forResource: "NBResourceBundle", ofType: "bundle") {
            return Bundle(path: path)
        } else {
            return nil
        }
    }

    private static func getResourceURL(_ name: String, withExtension: String, subdirectory: String) -> URL? {
        return bundle?.url(forResource: name, withExtension: withExtension, subdirectory: subdirectory)
    }
}
