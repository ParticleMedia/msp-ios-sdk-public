import Foundation

class NovaAsset {
    static func getBundle() -> Bundle? {
        return Bundle(for: NovaAsset.self)
    }
}
