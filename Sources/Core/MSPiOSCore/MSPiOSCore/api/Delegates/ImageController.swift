//
//  ImageController.swift
//  MSPiOSCore
//
//  Created by Shanyu Li on 2025/10/10.
//

import UIKit

public protocol ImageController: AnyObject {
    var delegate: ImageControllerDelegate? { get set }
    var contentMode: UIView.ContentMode { get set }
}

public protocol ImageControllerDelegate: AnyObject {
    func imageControllerDidStartDisplaying(_ controller: ImageController?)
}

public extension ImageControllerDelegate {
    func imageControllerDidStartDisplaying(_ controller: ImageController?) {}
}
