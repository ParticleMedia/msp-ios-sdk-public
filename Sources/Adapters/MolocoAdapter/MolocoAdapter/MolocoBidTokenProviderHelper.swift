//
//  MolocoBidTokenProviderHelper.swift
//  MolocoAdapter
//
//  Created by Mingming Luo on 2025/11/21.
//

import Foundation
import MSPiOSCore
import MolocoSDK

public class MolocoBidTokenProviderHelper: MolocoBidTokenProvider {
    public init() {
        
    }
    
    public func fetch(completeListener: any MolocoBidTokenListener, context: Any) {
        Moloco.shared.getBidToken(params: .init(mediation: "")) { bidToken, error in
            if error != nil {
                MSPLogger.shared.info(message: "Failed to get moloco bid token: \(String(describing: error?.localizedDescription))")
                completeListener.onComplete(molocoBidToken: "")
                return 
            }
            
            if let bidToken = bidToken {
                MSPLogger.shared.info(message: "Get moloco bid token successfully")
                completeListener.onComplete(molocoBidToken: bidToken)
            } else {
                MSPLogger.shared.info(message: "Failed to get moloco bid token: bidToken is nil")
                completeListener.onComplete(molocoBidToken: "")
            }
            
        }
    }
}
