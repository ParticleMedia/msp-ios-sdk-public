//import shared

import Foundation
import MSPiOSCore

public class FacebookManager: AdNetworkManager {
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        FacebookAdapter()
    }
}
