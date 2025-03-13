//
//  NativeAd.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 7/9/24.
//

import Foundation

open class NativeAd: MSPAd {
    public var title: String
    public var body: String
    public var advertiser: String
    public var callToAction: String
    public var optionsView: Any?
    public var mediaView: Any?
    public var mediaController: MediaController?
    public var nativeAdView: Any?
    
    public init(adNetworkAdapter: AdNetworkAdapter, builder: Builder) {
        self.title = builder.title
        self.body = builder.body
        self.advertiser = builder.advertiser
        self.callToAction = builder.callToAction
        self.optionsView = builder.optionsView
        self.mediaView = builder.mediaView
        self.mediaController = builder.mediaController
        super.init(adNetworkAdapter: adNetworkAdapter)
    }
    
    public init(adNetworkAdapter: AdNetworkAdapter,
                title: String,
                body: String,
                advertiser: String,
                callToAction: String) {
        self.title = title
        self.body = body
        self.advertiser = advertiser
        self.callToAction = callToAction
        super.init(adNetworkAdapter: adNetworkAdapter)
    }
    
    public func prepareViewForInteraction(nativeAdView: Any) {
        
    }
    
    public class Builder {
        public let adNetworkAdapter: AdNetworkAdapter
        public var title: String = ""
        public var body: String = ""
        public var advertiser: String = ""
        public var callToAction: String = ""
        public var optionsView: Any?
        public var mediaView: Any?
        public var mediaController: MediaController?
        
        public init(adNetworkAdapter: AdNetworkAdapter) {
            self.adNetworkAdapter = adNetworkAdapter
        }
        
        @discardableResult
        public func title(_ title: String) -> Builder {
            self.title = title
            return self
        }
        
        @discardableResult
        public func body(_ body: String) -> Builder {
            self.body = body
            return self
        }
        
        @discardableResult
        public func advertiser(_ advertiser: String) -> Builder {
            self.advertiser = advertiser
            return self
        }
        
        @discardableResult
        public func callToAction(_ callToAction: String) -> Builder {
            self.callToAction = callToAction
            return self
        }
        
        @discardableResult
        public func optionsView(_ optionsView: Any) -> Builder {
            self.optionsView = optionsView
            return self
        }
        
        @discardableResult
        public func mediaView(_ mediaView: Any) -> Builder {
            self.mediaView = mediaView
            return self
        }
        
        @discardableResult
        public func mediaController(_ mediaController: MediaController) -> Builder {
            self.mediaController = mediaController
            return self
        }
        
        public func build() -> NativeAd {
            return NativeAd(adNetworkAdapter: adNetworkAdapter, builder: self)
        }
    }
}

