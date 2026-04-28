//
//  NovaResource.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/9/26.
//

import Foundation

class NovaResource {
    // MARK: Internal

    static func getJSScriptResourceURL(_ name: String) -> URL? {
        getResourceURL(name, withExtension: "js", subdirectory: "Scripts")
    }

    static func getGIFResourceURL(_ name: String) -> URL? {
        getResourceURL(name, withExtension: "gif", subdirectory: "GIF")
    }

    // MARK: Private

    static var resourceBundle: Bundle? {
        if let path = Bundle(for: NovaResource.self).path(forResource: "NBResourceBundle", ofType: "bundle") {
            return Bundle(path: path)
        }
        return nil
    }

    private static func getResourceURL(_ name: String, withExtension: String, subdirectory: String) -> URL? {
        resourceBundle?.url(forResource: name, withExtension: withExtension, subdirectory: subdirectory)
    }
}
