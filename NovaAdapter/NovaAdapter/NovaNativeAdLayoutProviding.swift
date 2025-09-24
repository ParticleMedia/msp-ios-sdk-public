import NovaCore
import MSPiOSCore

public protocol NovaNativeAdLayoutProviding {
    var layout: NovaNativeLayoutStyle? { get }
}

extension MSPiOSCore.NativeAd: NovaNativeAdLayoutProviding {
    public var layout: NovaNativeLayoutStyle? {
        if let novaAd = self as? NovaNativeAd {
            return novaAd.layout
        }
        return nil
    }
}
