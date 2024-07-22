//
//  MSPNativeAdContainer.swift
//  MSPCore
//
//  Created by Huanzhi Zhang on 7/16/24.
//

import Foundation
import UIKit
import MSPiOSCore

open class MSPNativeAdContainer: UIView {
    
    public var nativeAd: NativeAd
    public var rootViewController: UIViewController
    
    public var nativeAdView: UIView?
    public var titleLabel: UILabel?
    public var bodyLabel: UILabel?
    public var advertiserLabel: UILabel?
    public var callToActionButton: UIButton?
    public var mediaView: UIView?
    
    public init(nativeAd: NativeAd, rootViewController: UIViewController) {
        self.nativeAd = nativeAd
        self.rootViewController = rootViewController
        super.init(frame: .zero)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
