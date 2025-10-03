import Foundation
import MSPiOSCore
//import shared

public class FacebookManager: AdNetworkManager {
    
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        return FacebookAdapter()
    }

}
