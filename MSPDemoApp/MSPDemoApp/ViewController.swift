//
//  ViewController.swift
//  MSPDemoApp
//
//  Created by Huanzhi Zhang on 4/29/24.
//

import UIKit
import MSPCore
import GoogleAdapter
import PrebidAdapter
//import MSPiOSCore
import shared

class ViewController: UIViewController {
    
    @IBOutlet var appBannerView: UIView!
    weak var adLoader: iOSAdLoader?

    override func viewDidLoad() {
        //google test ad config: msp-android-foryou-large-display_gg
        super.viewDidLoad()
        var adLoader = iOSAdLoader()
        self.adLoader = adLoader
        let adRequest = AdRequest(customParams: [String: String](),
                                  geo: Geo(city: "Beijing", stateCode: "12345", zipCode: "12345", lat: "12345", lon: "12345"),
                                  context: nil,
                                  adaptiveBannerSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
                                  adSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
                                  placementId: "msp-android-article-inside-native_gg",
                                  adFormat: "native",
                                  isCacheSupported: false)
        adLoader.loadAd(placementId: "msp-android-article-inside-native_gg",
                        adListener: self,
                        context: self,
                        adRequest: adRequest,
                        rootViewController:self)
        // Do any additional setup after loading the view.
    }


}

extension ViewController: AdListener {
    func onAdLoaded(placementId: String) {
        
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
        if ad is PrebidAd {
            let prebidAd = ad as? PrebidAd
            if let adView = prebidAd?.adView {
                appBannerView.backgroundColor = .red
                appBannerView.addSubview(adView)
                NSLayoutConstraint.activate([
                    adView.centerYAnchor.constraint(equalTo: appBannerView.centerYAnchor),
                    adView.leadingAnchor.constraint(equalTo: appBannerView.leadingAnchor),
                    adView.widthAnchor.constraint(lessThanOrEqualTo: appBannerView.widthAnchor),
                    adView.heightAnchor.constraint(lessThanOrEqualTo: appBannerView.heightAnchor),
                ])
            }
        } else if ad is GoogleAd {
            let googleAd = ad as? GoogleAd
            if let adView = googleAd?.adView {
                appBannerView.backgroundColor = .red
                appBannerView.addSubview(adView)
                NSLayoutConstraint.activate([
                    adView.centerYAnchor.constraint(equalTo: appBannerView.centerYAnchor),
                    adView.leadingAnchor.constraint(equalTo: appBannerView.leadingAnchor),
                    adView.widthAnchor.constraint(lessThanOrEqualTo: appBannerView.widthAnchor),
                    adView.heightAnchor.constraint(lessThanOrEqualTo: appBannerView.heightAnchor),
                ])
            }
        } else if ad is GoogleNativeAd {
            let googleNativeAd = ad as? GoogleNativeAd
            if let nativeAdItem = googleNativeAd?.nativeAdItem {
                var demoGoogleNativeAdView = DemoGoogleNativeAdView()
                
                appBannerView.addSubview(demoGoogleNativeAdView)
                NSLayoutConstraint.activate([
                    demoGoogleNativeAdView.centerYAnchor.constraint(equalTo: appBannerView.centerYAnchor),
                    demoGoogleNativeAdView.leadingAnchor.constraint(equalTo: appBannerView.leadingAnchor),
                    demoGoogleNativeAdView.widthAnchor.constraint(lessThanOrEqualTo: appBannerView.widthAnchor),
                    demoGoogleNativeAdView.heightAnchor.constraint(lessThanOrEqualTo: appBannerView.heightAnchor),
                ])
                
                demoGoogleNativeAdView.setUpView()
                demoGoogleNativeAdView.bindView(nativeAd: nativeAdItem)
                //demoGoogleNativeAdView.setUpView()
                
                /*
                appBannerView.addSubview(demoGoogleNativeAdView)
                NSLayoutConstraint.activate([
                    demoGoogleNativeAdView.centerYAnchor.constraint(equalTo: appBannerView.centerYAnchor),
                    demoGoogleNativeAdView.leadingAnchor.constraint(equalTo: appBannerView.leadingAnchor),
                    demoGoogleNativeAdView.widthAnchor.constraint(lessThanOrEqualTo: appBannerView.widthAnchor),
                    demoGoogleNativeAdView.heightAnchor.constraint(lessThanOrEqualTo: appBannerView.heightAnchor),
                ])
                 */
            }
        }
    }
    
    func onError(msg: String) {
        
    }
}
