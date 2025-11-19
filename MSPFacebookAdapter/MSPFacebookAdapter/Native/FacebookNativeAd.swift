
import Foundation
import UIKit
//import shared
import MSPiOSCore
#if SWIFT_PACKAGE
import FBAudienceNetworkWrapper
#else
import FBAudienceNetwork
#endif

public class FacebookNativeAd: NativeAd {
    public var nativeAdItem: FBNativeAd?
    public var priceInDollar: Double?
    
    public override func isValid() -> Bool {
        return nativeAdItem != nil
    }
}
