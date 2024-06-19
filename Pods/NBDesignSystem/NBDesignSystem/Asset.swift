import Foundation

class Asset {
    static func getBundle() -> Bundle? {
        let url = Bundle(for: Asset.self).url(forResource: "NBResourceBundle", withExtension: "bundle") ?? Bundle.main.bundleURL
        return Bundle(url: url)
    }
}
