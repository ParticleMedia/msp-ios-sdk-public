//
//  MSPNativeAdContainer.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 11/1/24.
//
import Foundation
import UIKit


public protocol MSPNativeAdContainer: UIView {
    
    func getTitle() -> UILabel?
    
    func getbody() -> UILabel?
    
    func getAdvertiser() -> UILabel?
    
    func getCallToAction() -> UIButton?
    
    func getMedia() -> UIView?
    
}
