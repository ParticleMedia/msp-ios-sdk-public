//
//  PlayableController.swift
//  MSPiOSCore
//
//  Created by Shanyu Li on 2025/9/28.
//

public enum PlayableRenderMode {
    case auto
    case imageOrVideo
    case playable
}

public protocol PlayableController: AnyObject {
    var renderMode: PlayableRenderMode { get set }
}
