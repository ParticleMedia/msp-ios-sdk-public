//
//  GoogleManager.swift
//  GoogleAdapter
//
//  Created by Huanzhi Zhang on 5/15/24.
//

import Foundation
import MSPiOSCore

public class GoogleManager: AdNetworkManager {
    public init() {
        
    }
    
    public func getAdNetworkAdapter() -> any MSPiOSCore.AdNetworkAdapter {
        return GADAdLoder()
    }
}
