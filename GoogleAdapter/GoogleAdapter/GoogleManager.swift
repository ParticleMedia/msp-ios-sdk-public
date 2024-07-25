import Foundation
import MSPiOSCore
//import shared

public class GoogleManager: AdNetworkManager {
    
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        return GoogleAdapter()
    }

}
