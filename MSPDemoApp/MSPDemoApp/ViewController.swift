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
import NovaAdapter
//import MSPiOSCore
import NovaCore
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
                                  placementId: "msp-ios-foryou-large-display",
                                  adFormat: "native",
                                  isCacheSupported: false)
        adLoader.loadAd(placementId: "msp-ios-foryou-large-display",
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
                
                //appBannerView.addSubview(demoGoogleNativeAdView)
                self.view.addSubview(demoGoogleNativeAdView)
                demoGoogleNativeAdView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    demoGoogleNativeAdView.leadingAnchor.constraint(lessThanOrEqualTo: self.view.leadingAnchor, constant: 100),
                    demoGoogleNativeAdView.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor),
                    demoGoogleNativeAdView.topAnchor.constraint(lessThanOrEqualTo: self.view.topAnchor, constant: 100),
                    demoGoogleNativeAdView.bottomAnchor.constraint(lessThanOrEqualTo: self.view.bottomAnchor),
                ])
                
                demoGoogleNativeAdView.bindView(nativeAd: nativeAdItem)
                demoGoogleNativeAdView.setUpView(nativeAd: nativeAdItem)
            }
        } else if ad is NovaNativeAd {
            let novaNativeAd = ad as? NovaNativeAd
            if let nativeAdItem = novaNativeAd?.nativeAdItem {
                
                let adOpenActionHandler = NovaAdOpenActionHandler()
                let actionHandlerMaster = ActionHandlerMaster(actionHandlers: [adOpenActionHandler])
                let demoNovaNativeAdView = DemoNovaNativeAdView(actionHandler: actionHandlerMaster)
                self.view.addSubview(demoNovaNativeAdView)
                demoNovaNativeAdView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    demoNovaNativeAdView.leadingAnchor.constraint(lessThanOrEqualTo: self.view.leadingAnchor, constant: 100),
                    demoNovaNativeAdView.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor),
                    demoNovaNativeAdView.topAnchor.constraint(lessThanOrEqualTo: self.view.topAnchor, constant: 100),
                    demoNovaNativeAdView.bottomAnchor.constraint(lessThanOrEqualTo: self.view.bottomAnchor),
                ])
                
                demoNovaNativeAdView.bindView(nativeAd: nativeAdItem)
                demoNovaNativeAdView.setUpView(nativeAd: nativeAdItem)
                 
            }
        }
    }
    
    func onError(msg: String) {
        
    }
}
