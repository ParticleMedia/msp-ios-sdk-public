//import shared
import Foundation
import UIKit
import MSPiOSCore
import FBAudienceNetwork

public class FacebookBidTokenProviderHelper: FacebookBidTokenProvider {
    public init() {
        
    }
    
    public func fetch(completeListener: any FacebookBidTokenListener, context: Any) {
        let bidToken = FBAdSettings.bidderToken
        completeListener.onComplete(bidToken: bidToken)
    }
}
