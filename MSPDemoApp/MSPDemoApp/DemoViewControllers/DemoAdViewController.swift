import Foundation
import UIKit

import MSPCore
import MSPiOSCore
import AppTrackingTransparency
import PrebidMobile

public enum AdType: String {
    case prebidBanner
    case googleBanner
    case googleNative
    case novaNative
    case googleInterstitial
    case novaInterstitial
    case facebookNative
    case facebookInterstitial
}

class DemoAdViewController: UIViewController {
    public let adType: AdType
    public var adLoader: MSPAdLoader?
    public var nativeAdView: NativeAdView?
    public var isCtaShown = false
    
    private lazy var placementId = {
        switch adType {
        case .prebidBanner:
            return "demo-ios-article-top"
        case .googleBanner:
            return "demo-ios-article-top"
        case .googleNative:
            return "demo-ios-foryou-large"
        case .novaNative:
            return "demo-ios-foryou-large"
        case .googleInterstitial:
            return "demo-ios-article-top"
        case .novaInterstitial:
            return "demo-ios-launch-fullscreen"
        case .facebookNative:
            return "demo-ios-foryou-large"
        case .facebookInterstitial:
            return "demo-ios-launch-fullscreen"
        }
    }()
    
    private lazy var adFormat: MSPiOSCore.AdFormat = {
        switch adType {
        case .prebidBanner, .googleBanner :
            return .banner
    
        case .googleNative, .novaNative, .facebookNative:
            return .native
        case .googleInterstitial, .novaInterstitial, .facebookInterstitial:
            return .interstitial
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
        if adType == .novaNative || adType == .novaInterstitial {
            testParams["test"] = "{\"ad_network\":\"msp_nova\",\"test_ad\":true}"
        } else if adType == .prebidBanner {
            testParams["test"] = "{\"ad_network\":\"pubmatic\",\"test_ad\":true}"
        } else if adType == .googleBanner || adType == .googleInterstitial || adType == .googleNative {
            testParams["test"] = "{\"ad_network\":\"msp_google\",\"test_ad\":true}"
        } else if adType == .facebookNative || adType == .facebookInterstitial {
            testParams["test"] = "{\"ad_network\":\"msp_fb\",\"test_ad\":true}"
        }
         
        
        let adRequest = AdRequest(customParams: customParams,
                                  geo: nil,
                                  context: nil,
                                  adaptiveBannerSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
                                  adSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
                                  placementId: placementId,
                                  adFormat: adFormat,
                                  isCacheSupported: true,
                                  testParams: testParams)
        adLoader.loadAd(placementId: placementId,
                        adListener: self,
                        adRequest: adRequest)
    }

}

extension DemoAdViewController: AdListener {
    func getRootViewController() -> UIViewController? {
        return self
    }
    
    func onAdDismissed(ad: MSPiOSCore.InterstitialAd) {
        
    }
    
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
                let nativeAdContainer = DemoNativeAdContainer(frame: CGRect(x: 0, y: 0, width: 300, height: 250))
                let nativeAdView = NativeAdView(nativeAd: nativeAd, nativeAdContainer: nativeAdContainer)
                self.nativeAdView = nativeAdView
                self.view.addSubview(nativeAdView)
                //self.nativeAdView?.callToActionButton?.isHidden = true
                nativeAdView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    nativeAdView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                    nativeAdView.topAnchor.constraint(lessThanOrEqualTo: self.view.topAnchor, constant: 200),
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
        } else if ad is InterstitialAd,
                  let interstitialAd = ad as? InterstitialAd {
            interstitialAd.show()
        }
    }
    
    func onError(msg: String) {
        print(msg)
    }
}
