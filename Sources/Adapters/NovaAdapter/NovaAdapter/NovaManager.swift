//import shared

import Foundation
import MSPiOSCore

public class NovaManager: AdNetworkManager {
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        NovaAdapter()
    }
}
