import Foundation

class NovaAsset {
    static func getBundle() -> Bundle? {
        let url = Bundle(for: NovaAsset.self).url(forResource: "NBResourceBundle", withExtension: "bundle") ?? Bundle.main.bundleURL
        return Bundle(url: url)
    }
}
