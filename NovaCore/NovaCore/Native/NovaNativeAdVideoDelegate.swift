//
//  NovaNativeAdVideoDelegate.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 8/14/24.
//

import Foundation

@objc public protocol NovaNativeAdVideoDelegate: AnyObject {
    @objc optional func playerCurrentTimeDidChange(currentTime: Double, durationTime: Double)
    
    @objc optional func playerDidPlayToEndTime()
}
