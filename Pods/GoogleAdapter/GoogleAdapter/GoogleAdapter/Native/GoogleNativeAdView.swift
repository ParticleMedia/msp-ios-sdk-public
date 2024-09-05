//
//  GoogleNativeAdView.swift
//  GoogleAdapter
//
//  Created by Huanzhi Zhang on 6/13/24.
//

import Foundation
import GoogleMobileAds

open class GoogleNativeAdView: UIView {
    public var titleLabel: UILabel?
    public var bodyLabel: UILabel?
    public var advertiserLabel: UILabel?
    public var callToActionButton: UIButton?
    
    public let gadMediaView: GADMediaView = {
        let mediaView = GADMediaView()
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.contentMode = .scaleAspectFill
        return mediaView
    }()
    
    public let nativeAdView: GADNativeAdView = {
        let view = GADNativeAdView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    open func setUpView() {
        self.addSubview(self.nativeAdView)
        NSLayoutConstraint.activate([
            self.nativeAdView.topAnchor.constraint(equalTo: self.topAnchor),
            self.nativeAdView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.nativeAdView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.nativeAdView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
        ])
    }
    
    public func bindViewWithNativeViewBinder(binder: GoogleNativeAdViewBinder, nativeAd: GADNativeAd) {
        
        if let titleLabelTag = binder.titleLabelTag {
            nativeAdView.headlineView = nativeAdView.viewWithTag(titleLabelTag)
        }
        if let bodyLabelTag = binder.bodyLabelTag {
            nativeAdView.bodyView = nativeAdView.viewWithTag(bodyLabelTag)
        }
        if let advertiserLabelTag = binder.advertiserLabelTag {
            nativeAdView.advertiserView = nativeAdView.viewWithTag(advertiserLabelTag)
        }
        if let callToActionButtonTag = binder.callToActionButtonTag {
            nativeAdView.callToActionView = nativeAdView.viewWithTag(callToActionButtonTag)
        }
        if let mediaViewTag = binder.mediaViewTag {
            nativeAdView.mediaView = nativeAdView.viewWithTag(mediaViewTag) as? GADMediaView
        }
        
        self.setUpView(nativeAd: nativeAd)
    }
    
    public func bindView(nativeAd: GADNativeAd) {
        titleLabel = UILabel()
        bodyLabel = UILabel()
        advertiserLabel = UILabel()
        callToActionButton = UIButton(type: .custom)
        
        self.nativeAdView.advertiserView = self.advertiserLabel
        self.nativeAdView.headlineView = self.titleLabel
        self.nativeAdView.bodyView = self.bodyLabel
        self.nativeAdView.callToActionView = self.callToActionButton
        self.nativeAdView.callToActionView?.isUserInteractionEnabled = false
        self.nativeAdView.mediaView = self.gadMediaView
    }
    
    open func setUpView(nativeAd: GADNativeAd) {
        
        self.setUpView()
        
        (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
        (nativeAdView.bodyView as? UILabel)?.text = nativeAd.headline
        (nativeAdView.advertiserView as? UILabel)?.text = nativeAd.headline
        self.nativeAdView.callToActionView?.isUserInteractionEnabled = false
        self.gadMediaView.translatesAutoresizingMaskIntoConstraints = false
        self.gadMediaView.contentMode = .scaleAspectFill
        self.gadMediaView.mediaContent = nativeAd.mediaContent
        self.nativeAdView.mediaView = gadMediaView
        
        self.nativeAdView.nativeAd = nativeAd
    }
}
