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
import MSPiOSCore
import NovaCore
//import shared
import MetaAdapter
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
        let adRequest = AdRequest(customParams: customParams,
                                  geo: Geo(city: "Beijing", stateCode: "12345", zipCode: "12345", lat: "12345", lon: "12345"),
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
            let nativeAdViewBinder = DemoNativeAdViewBinder(nativeAd: nativeAd)
            let nativeAdView = NativeAdView(nativeAd: nativeAd, rootViewController: self, nativeAdViewBinder: nativeAdViewBinder)
            //nativeAd.adNetworkAdapter.prepareViewForInteraction(nativeAd: nativeAd, nativeAdView: nativeAdView)
        
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
    /*
    // deprecated api
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
                    demoGoogleNativeAdView.widthAnchor.constraint(equalToConstant: 300.0)
                ])
                
                demoGoogleNativeAdView.bindView(nativeAd: nativeAdItem)
                demoGoogleNativeAdView.setUpView(nativeAd: nativeAdItem)
            }
        } else if ad is NovaNativeAd {
            let novaNativeAd = ad as? NovaNativeAd
            if let nativeAdItem = novaNativeAd?.nativeAdItem {
                
                let adOpenActionHandler = NovaAdOpenActionHandler()
                let actionHandlerMaster = ActionHandlerMaster(actionHandlers: [adOpenActionHandler])
                let demoNovaNativeAdView = DemoNovaNativeAdView(actionHandler: actionHandlerMaster, rootViewController: self)
                self.view.addSubview(demoNovaNativeAdView)
                demoNovaNativeAdView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    demoNovaNativeAdView.leadingAnchor.constraint(lessThanOrEqualTo: self.view.leadingAnchor, constant: 50),
                    demoNovaNativeAdView.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor),
                    demoNovaNativeAdView.topAnchor.constraint(lessThanOrEqualTo: self.view.topAnchor, constant: 50),
                    demoNovaNativeAdView.bottomAnchor.constraint(lessThanOrEqualTo: self.view.bottomAnchor),
                    demoNovaNativeAdView.widthAnchor.constraint(equalToConstant: 300.0)
                ])
                
                demoNovaNativeAdView.bindView(nativeAd: nativeAdItem)
                demoNovaNativeAdView.setUpView(nativeAd: nativeAdItem)
                 
            }
        } else if ad is MetaNativeAd {
            let metaNativeAd = ad as? MetaNativeAd
            if let nativeAdItem = metaNativeAd?.nativeAdItem {
                let demoMetaNativeAdView = DemoMetaNativeAdView()
                self.view.addSubview(demoMetaNativeAdView)
                demoMetaNativeAdView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    demoMetaNativeAdView.leadingAnchor.constraint(lessThanOrEqualTo: self.view.leadingAnchor, constant: 100),
                    demoMetaNativeAdView.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor),
                    demoMetaNativeAdView.topAnchor.constraint(lessThanOrEqualTo: self.view.topAnchor, constant: 100),
                    demoMetaNativeAdView.bottomAnchor.constraint(lessThanOrEqualTo: self.view.bottomAnchor),
                ])
                
                demoMetaNativeAdView.bindView(nativeAd: nativeAdItem)
                demoMetaNativeAdView.setUpView(nativeAd: nativeAdItem)
            }
        } else if ad is NativeAd {
            //let demoNativeAdView = MSPNativeAdView()
        }
    }
     */
    
    func onError(msg: String) {
        print(msg)
    }
}
