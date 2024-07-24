//
//  NovaManager.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 6/21/24.
//

import Foundation
import MSPiOSCore
//import shared

public class NovaManager: AdNetworkManager {
    
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        return NovaAdapter()
    }

}
