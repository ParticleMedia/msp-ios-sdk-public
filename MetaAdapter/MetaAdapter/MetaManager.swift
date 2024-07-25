import Foundation
import MSPiOSCore
//import shared

public class MetaManager: AdNetworkManager {
    
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        return FacebookAdapter()
    }

}
