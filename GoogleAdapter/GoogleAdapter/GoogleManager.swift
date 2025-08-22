import Foundation
import MSPiOSCore
//import shared

public class GoogleManager: AdNetworkManager {
    
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        return GoogleAdapter()
    }
    
    public override func getAdBidder(bidderPlacementId: String, bidderFormat: AdFormat?) -> Bidder? {
        return GoogleBidder(name: "google", bidderPlacementId: bidderPlacementId, bidderFormat: bidderFormat)
    }

}
