//import shared
import MSPiOSCore
import Foundation
import NovaCore

public class NovaNativeAd: NativeAd {
    public var nativeAdItem: NovaNativeAdItem?
    public var priceInDollar: Double?
    
    public override func isValid() -> Bool {
        return nativeAdItem != nil
    }
}
