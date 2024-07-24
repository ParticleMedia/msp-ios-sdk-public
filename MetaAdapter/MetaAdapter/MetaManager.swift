//
//  MetaManager.swift
//  MetaAdapter
//
//  Created by Huanzhi Zhang on 6/26/24.
//

import Foundation
import MSPiOSCore
//import shared

public class MetaManager: AdNetworkManager {
    
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        return FacebookAdapter()
    }

}
