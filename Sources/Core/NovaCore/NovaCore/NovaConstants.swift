//
//  NovaConstants.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/4/24.
//

import Foundation

public class NovaConstants {
    public static let shared = NovaConstants()

    public var NovaEventHostUrl = "https://dsp.newsbreak.com"

    public var version = NovaConstants.getNovaVersion()

    static func getNovaVersion() -> String {
        let frameworkBundle = Bundle(for: NovaConstants.self)
        let resourceBundle = getResourceBundle(from: frameworkBundle)

        if let version = readSDKVersion(from: resourceBundle) {
            return version
        }

        if let version = frameworkBundle.infoDictionary?["CFBundleShortVersionString"] as? String,
            !version.isEmpty
        {
            return version
        }

        return "3.4.1"
    }

    private static func getResourceBundle(from frameworkBundle: Bundle) -> Bundle {
        if let url = frameworkBundle.url(forResource: "NBResourceBundle", withExtension: "bundle"),
            let nestedBundle = Bundle(url: url)
        {
            return nestedBundle
        }

        if let url = Bundle.main.url(forResource: "NBResourceBundle", withExtension: "bundle"),
            let nestedBundle = Bundle(url: url)
        {
            return nestedBundle
        }

        return frameworkBundle
    }

    private static func readSDKVersion(from bundle: Bundle) -> String? {
        guard let plistURL = bundle.url(forResource: "Config", withExtension: "plist"),
            let data = try? Data(contentsOf: plistURL),
            let plistData = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let plist = plistData as? [String: Any],
            let version = plist["SDKVersion"] as? String,
            !version.isEmpty
        else {
            return nil
        }

        return version
    }
}
