//import shared
import FBAudienceNetwork
import Foundation
import MSPiOSCore
import UIKit

public class FacebookBidTokenProviderHelper: FacebookBidTokenProvider {
    public init() {
    }

    public func fetch(completeListener: any FacebookBidTokenListener, context: Any) {
        let bidToken = FBAdSettings.bidderToken
        completeListener.onComplete(bidToken: bidToken)
    }
}
