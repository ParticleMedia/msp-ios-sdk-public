import MSPiOSCore
import NovaCore

/// Exposes the Nova ad `high_value` flag on the cross-bidder `MSPiOSCore.NativeAd`
/// surface so the host app can read it without reaching into Nova internals.
public protocol NovaNativeAdHighValueProviding {
    /// `true` when the ad-server marked this Nova native ad as high-value traffic.
    /// Returns `false` for non-Nova bidders or when the flag is absent.
    var highValue: Bool { get }
}

extension MSPiOSCore.NativeAd: NovaNativeAdHighValueProviding {
    public var highValue: Bool {
        if let novaAd = self as? NovaNativeAd {
            return novaAd.nativeAdItem?.highValue ?? false
        }
        return false
    }
}
