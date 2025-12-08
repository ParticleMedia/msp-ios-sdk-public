import Foundation

class NovaAsset {
    static func getBundle() -> Bundle? {
        if let bundle = NovaResource.resourceBundle {
            return bundle
        }
        return Bundle(for: NovaAsset.self)
    }
}
