//
//  AdMediaContainer.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 7/9/24.
//

import Foundation

public protocol AdMediaContainer: AnyObject {
    var imageController: (any ImageController)? { get }
    var videoController: (any VideoController)? { get }
    var playableController: (any PlayableController)? { get }
}
