//import shared
import FBAudienceNetwork
import Foundation
import MSPiOSCore
import UIKit

public class FacebookNativeAd: NativeAd {
    public var nativeAdItem: FBNativeAd?
    public var priceInDollar: Double?

    public override func isValid() -> Bool {
        nativeAdItem != nil
    }
}
