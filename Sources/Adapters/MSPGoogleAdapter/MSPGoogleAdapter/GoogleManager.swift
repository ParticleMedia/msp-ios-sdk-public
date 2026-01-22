//import shared

import Foundation
import MSPiOSCore

public class GoogleManager: AdNetworkManager {
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        GoogleAdapter()
    }

    public override func getAdBidder(bidderPlacementId: String, bidderFormat: AdFormat?) -> Bidder? {
        GoogleBidder(name: "google", bidderPlacementId: bidderPlacementId, bidderFormat: bidderFormat)
    }
}
