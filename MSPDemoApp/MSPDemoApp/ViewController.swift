//
//  ViewController.swift
//  MSPDemoApp
//
//  Created by Huanzhi Zhang on 4/29/24.
//

import UIKit
import MSPCore
//import GoogleAdapter
//import PrebidAdapter
import NovaAdapter
import MSPiOSCore
//import NovaCore
//import shared
//import MetaAdapter
import AppTrackingTransparency

class ViewController: UIViewController {
    
    @IBOutlet var appBannerView: UIView!
    weak var adLoader: MSPAdLoader?

    override func viewDidLoad() {
        //google test ad config: msp-android-foryou-large-display_gg
        super.viewDidLoad()
        
        var adLoader = MSPAdLoader()
        self.adLoader = adLoader
        var customParams = [String: String]()
        customParams["user_id"] = "143378797"
        //customParams["test"] = "{\"ad_network\":\"msp_nova\",\"test_ad\":true}"
        customParams["profile_id"] = "09hbNFOl"
        let adRequest = AdRequest(customParams: customParams,
                                  geo: Geo(city: "San Francisco", stateCode: "CA", zipCode: "94102", lat: "37.79", lon: "-122.41"),
                                  context: nil,
                                  adaptiveBannerSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
                                  adSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
                                  placementId: "msp-ios-foryou-large-display-prod2",
                                  adFormat: .native,
                                  isCacheSupported: true)
        adLoader.loadAd(placementId: "msp-ios-foryou-large-display-prod2",
                        adListener: self,
                        context: self,
                        adRequest: adRequest,
                        rootViewController:self)
        
        //To test a ad creative
        //let novaAdLoader = MSP.shared.adNetworkAdapterProvider.getAdNetworkAdapterByName(adNetworkName: "Nova") as? NovaAdLoader
        //novaAdLoader?.loadTestAdCreative(adString:testAdString, adListener: self, context: self, adRequest: adRequest)
    }


}

extension ViewController: AdListener {
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
        if ad is NativeAd,
           let nativeAd = ad as? NativeAd {
            DispatchQueue.main.async{
                let nativeAdViewBinder = DemoNativeAdViewBinder(nativeAd: nativeAd)
                let nativeAdView = NativeAdView(nativeAd: nativeAd, rootViewController: self, nativeAdViewBinder: nativeAdViewBinder)

                self.view.addSubview(nativeAdView)
                nativeAdView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    nativeAdView.leadingAnchor.constraint(lessThanOrEqualTo: self.view.leadingAnchor, constant: 100),
                    nativeAdView.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor),
                    nativeAdView.topAnchor.constraint(lessThanOrEqualTo: self.view.topAnchor, constant: 100),
                    nativeAdView.bottomAnchor.constraint(lessThanOrEqualTo: self.view.bottomAnchor),
                    nativeAdView.widthAnchor.constraint(equalToConstant: 300.0)
                ])
            }
        }
    }
    
    func onError(msg: String) {
        print(msg)
    }
}
