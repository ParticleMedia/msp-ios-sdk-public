import Foundation
import MSPiOSCore
//import shared

public class NovaManager: AdNetworkManager {
    
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        return NovaAdapter()
    }

}
