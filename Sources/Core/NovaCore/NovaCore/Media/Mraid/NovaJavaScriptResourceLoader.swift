//
//  NovaJavaScriptResourceLoader.swift
//  NovaCore
//
//  Created by Shanyu Li on 2026/2/2.
//

import Foundation

enum NovaJavaScriptResourceLoader {
    static func loadScript(named resourceName: String) -> String {
        guard
            let url = NovaResource.getJSScriptResourceURL(resourceName)
                ?? Bundle.main.url(forResource: resourceName, withExtension: "js")
        else {
            assertionFailure("Failed to find \(resourceName).js in bundle")
            return ""
        }

        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            assertionFailure("Failed to load \(resourceName).js from bundle: \(error)")
            return ""
        }
    }
}
