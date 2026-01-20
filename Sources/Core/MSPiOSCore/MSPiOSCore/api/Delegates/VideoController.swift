//
//  VideoController.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 7/9/24.
//

import Foundation

public protocol VideoController: AnyObject {
    var delegate: VideoControllerDelegate? { get set }
    var muted: Bool { get set }
}

public protocol VideoControllerDelegate: AnyObject {
    func videoController(
        _ controller: VideoController?,
        loopCount: Int,
        didUpdateProgress currentTime: TimeInterval,
        videoLength: TimeInterval
    )
}
