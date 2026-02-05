//
//  MSPAd.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/11/24.
//
import Foundation

open class MSPAd {
    public var adNetworkAdapter: AdNetworkAdapter?
    public var adInfo: [String: Any]
    public weak var adListener: AdListener?
    public init(adNetworkAdapter: AdNetworkAdapter) {
        self.adNetworkAdapter = adNetworkAdapter
        self.adInfo = [String: Any]()
    }


    public func destroy() {
        adNetworkAdapter?.destroyAd()
    }

    public func sendHideAdEvent(reason: String, adScreenShot: Data? = nil, fullScreenShot: Data? = nil) {
        adNetworkAdapter?.sendHideAdEvent(reason: reason, adScreenShot: adScreenShot, fullScreenShot: fullScreenShot)
    }

    public func sendReportAdEvent(
        reason: String, description: String?, adScreenShot: Data? = nil, fullScreenShot: Data? = nil
    ) {
        adNetworkAdapter?.sendReportAdEvent(
            reason: reason, description: description, adScreenShot: adScreenShot, fullScreenShot: fullScreenShot)
    }

    open func isValid() -> Bool {
        true
    }
}
