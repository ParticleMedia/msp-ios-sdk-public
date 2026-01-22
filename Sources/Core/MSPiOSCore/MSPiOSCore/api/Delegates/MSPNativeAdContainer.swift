//
//  MSPNativeAdContainer.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 11/1/24.
//
import Foundation
import UIKit

public enum MSPNativeElement: Equatable {
    case title
    case body
    case advertiser
    case CTAButton
    case media
    case icon
}

public protocol MSPNativeAdContainer: UIView {
    func getTitle() -> UILabel?

    func getbody() -> UILabel?

    func getAdvertiser() -> UILabel?

    func getCallToAction() -> UIButton?

    func getMedia() -> UIView?

    func getIcon() -> UIImageView?

    func getCustomClickableViews() -> [UIView]?

    func getDisplayContext() -> [MSPNativeElement: MSPNativeDisplayContext]?
}

extension MSPNativeAdContainer {
    public func getDisplayContext() -> [MSPNativeElement: MSPNativeDisplayContext]? {
        nil
    }
}
