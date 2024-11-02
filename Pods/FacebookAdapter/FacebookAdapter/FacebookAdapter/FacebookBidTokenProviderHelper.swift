//import shared
import MSPiOSCore
import FBAudienceNetwork

import Foundation

public class FacebookBidTokenProviderHelper: FacebookBidTokenProvider {
    public init() {
        
    }
    
    public func fetch(completeListener: any FacebookBidTokenListener, context: Any) {
        let bidToken = FBAdSettings.bidderToken
        completeListener.onComplete(bidToken: bidToken)
    }
}
