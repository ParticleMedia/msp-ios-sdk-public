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
import MSPiOSCore

class ViewController: UIViewController {
    
    @IBOutlet var appBannerView: UIView!
    var adLoader: iOSAdLoader?

    override func viewDidLoad() {
        super.viewDidLoad()
        var adLoader = iOSAdLoader()
        self.adLoader = adLoader
        let adRequest = AdRequest(customParams: [String: String](),
                                  geo: Geo(city: "Beijing", stateCode: "12345", zipCode: "12345", lat: "12345", lon: "12345"),
                                  context: nil,
                                  adaptiveBannerSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
                                  adSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
                                  placementId: "msp-android-foryou-large-display_gg")
        adLoader.loadAd(placementId: "msp-android-foryou-large-display_gg",
                        adListener: self,
                        context: self,
                        adRequest: adRequest,
                        rootViewController:self)
        // Do any additional setup after loading the view.
    }


}

extension ViewController: AdListener {
    func onAdClick(ad: MSPAd) {
        
    }
    
    func onAdImpression(ad: MSPAd) {
        
    }
    
    func onAdLoaded(ad: MSPAd) {
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
        }
    }
    
    func onError(msg: String) {
        
    }
    
}

