//
//  MediaController.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 7/9/24.
//

import Foundation

public protocol MediaController {
    
    func addMediaListener(listener: MediaListener)
    
    func removeMediaListener(listener: MediaListener)
    
}
