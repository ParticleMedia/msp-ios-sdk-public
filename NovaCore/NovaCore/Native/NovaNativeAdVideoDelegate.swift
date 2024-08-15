//
//  NovaNativeAdVideoDelegate.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 8/14/24.
//

import Foundation

@objc public protocol NovaNativeAdVideoDelegate: AnyObject {
    func playerCurrentTimeDidChange(currentTime: Double, durationTime: Double)
}
