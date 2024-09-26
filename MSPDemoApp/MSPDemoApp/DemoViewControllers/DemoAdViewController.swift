//
//  PrebidBannerViewController.swift
//  MSPDemoApp
//
//  Created by Huanzhi Zhang on 9/9/24.
//

import Foundation
import UIKit

import MSPCore
//import GoogleAdapter
//import PrebidAdapter
//import NovaAdapter
import MSPiOSCore
//import NovaCore
//import shared
//import MetaAdapter
import AppTrackingTransparency
import PrebidMobile

public enum AdType: String {
    case prebidBanner
    case googleBanner
    case googleNative
    case novaNative
}

class DemoAdViewController: UIViewController {
    public let adType: AdType
    weak var adLoader: MSPAdLoader?
    public var nativeAdView: NativeAdView?
    public var isCtaShown = false
    
    private lazy var placementId = {
        switch adType {
        case .prebidBanner:
            return "demo-ios-article-top"
        case .googleBanner:
            return "demo-ios-article-top"
        case .googleNative:
            return ""
        case .novaNative:
            return ""
        }
    }()
    
    init(adType: AdType) {
        self.adType = adType
        super.init(nibName: nil, bundle: nil)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        var adLoader = MSPAdLoader()
        self.adLoader = adLoader
        var customParams = [String: String]()
        var testParams = [String: String]()
        customParams["user_id"] = ""
        customParams["profile_id"] = ""
        if adType == .novaNative {
            testParams["test"] = "{\"ad_network\":\"msp_nova\",\"test_ad\":true}"
        } else if adType == .prebidBanner {
            testParams["test"] = "{\"ad_network\":\"pubmatic\",\"test_ad\":true}"
        } else if adType == .googleBanner {
            testParams["test"] = "{\"ad_network\":\"msp_google\",\"test_ad\":true}"
        }
        let adRequest = AdRequest(customParams: customParams,
                                  geo: Geo(city: "San Francisco", stateCode: "CA", zipCode: "94102", lat: "37.79", lon: "-122.41"),
                                  context: nil,
                                  adaptiveBannerSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: true),
                                  adSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
                                  placementId: placementId,
                                  adFormat: .banner,
                                  isCacheSupported: true,
                                  testParams: testParams)
        adLoader.loadAd(placementId: placementId,
                        adListener: self,
                        context: self,
                        adRequest: adRequest,
                        rootViewController:self)
    }

}

extension DemoAdViewController: AdListener {
    func onAdLoaded(placementId: String) {
        if let ad = AdCache.shared.getAd(placementId: placementId) {
            self.onAdLoaded(ad: ad)
        }
    }
    
    func onAdClick(ad: MSPAd) {
        
    }
    
    func onAdImpression(ad: MSPAd) {
        
    }
    
    func onAdLoaded(ad: MSPAd) {
        if let priceInDollar = ad.adInfo["priceInDollar"],
           let priceInDollarValue = priceInDollar as? Double {
            print("demo price: \(priceInDollarValue)")
        }
        if ad is MSPiOSCore.NativeAd,
           let nativeAd = ad as? MSPiOSCore.NativeAd {
            
            DispatchQueue.main.async{
                let nativeAdViewBinder = DemoNativeAdViewBinder(nativeAd: nativeAd)
                let nativeAdView = NativeAdView(nativeAd: nativeAd, rootViewController: self, nativeAdViewBinder: nativeAdViewBinder)
                self.nativeAdView = nativeAdView
                self.view.addSubview(nativeAdView)
                //self.nativeAdView?.callToActionButton?.isHidden = true
                nativeAdView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    nativeAdView.leadingAnchor.constraint(lessThanOrEqualTo: self.view.leadingAnchor, constant: 100),
                    nativeAdView.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor),
                    nativeAdView.topAnchor.constraint(lessThanOrEqualTo: self.view.topAnchor, constant: 100),
                    nativeAdView.bottomAnchor.constraint(lessThanOrEqualTo: self.view.bottomAnchor),
                    nativeAdView.widthAnchor.constraint(equalToConstant: 300.0)
                ])
            }
             
        } else if ad is BannerAd,
                let bannerAd = ad as? BannerAd {
            let adView = bannerAd.adView
            adView.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(adView)
            NSLayoutConstraint.activate([
                adView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                adView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 200),
            ])
        }
    }
    
    func onError(msg: String) {
        print(msg)
    }
}
