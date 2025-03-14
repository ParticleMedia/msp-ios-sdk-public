//
//  MediaListener.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 7/9/24.
//

import Foundation

public protocol MediaListener: AnyObject {
    
    func onDurationUpdate(duration: UInt64)
    
    func onProgressUpdate(position: UInt64, bufferedPosition: UInt64)
    
}
