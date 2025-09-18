
import Foundation
//import shared
import MSPiOSCore
import FBAudienceNetwork

public class FacebookNativeAd: NativeAd {
    public var nativeAdItem: FBNativeAd?
    public var priceInDollar: Double?
    
    public override func isValid() -> Bool {
        return nativeAdItem != nil
    }
}
