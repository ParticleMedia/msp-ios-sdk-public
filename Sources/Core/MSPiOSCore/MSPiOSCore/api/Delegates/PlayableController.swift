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
    var delegate: PlayableControllerDelegate? { get set }
    var renderMode: PlayableRenderMode { get set }
}

public protocol PlayableControllerDelegate: AnyObject {
    func playableControllerDidRequestClose(_ controller: PlayableController?)
}

public extension PlayableControllerDelegate {
    func playableControllerDidRequestClose(_ controller: PlayableController?) {}
}
