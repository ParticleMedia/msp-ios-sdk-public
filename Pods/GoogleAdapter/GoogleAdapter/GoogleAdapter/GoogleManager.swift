//
//  GoogleManager.swift
//  GoogleAdapter
//
//  Created by Huanzhi Zhang on 5/15/24.
//

import Foundation
//import MSPiOSCore
import shared

public class GoogleManager: AdNetworkManager {
    //public override init() {
    //
    //}
    
    public override func getAdNetworkAdapter() -> AdNetworkAdapter? {
        return GADAdLoder()
    }

}
