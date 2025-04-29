import Foundation
import UIKit

import MSPCore
import MSPiOSCore
import AppTrackingTransparency
import PrebidMobile
import MobilefuseAdapter

public enum AdType: String {
    case prebidBanner
    case googleBanner
    case googleNative
    case novaNative
    case googleInterstitial
    
    case novaInterstitialHorizontalImage
    case novaInterstitialVerticalImage
    case novaInterstitialHorizontalVideo
    case novaInterstitialVerticalVideo
    case novaInterstitialHighEngagement
    
    case facebookNative
    case facebookInterstitial
    
    case unityBanner
    case unityInterstitial
    case unityNative
    
    case inmobiBanner
    case inmobiInterstitial
    case inmobiNative
    
    case mobilefuseBanner
    case mobilefuseInterstitial
    case mobilefuseNative
    
    case pubmaticBanner
    case pubmaticInterstitial
    case pubmaticNative
    
    case mintegralBanner
    case mintegralInterstitial
    case mintegralNative
    
    case clientBiddingBanner
}

class DemoAdViewController: UIViewController {
    public let adType: AdType
    public var adLoader: MSPAdLoader?
    public var nativeAdView: NativeAdView?
    public var isCtaShown = false
    
    public var ad: MSPAd?
    
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
        case .novaInterstitialHorizontalImage, .novaInterstitialVerticalImage, .novaInterstitialHorizontalVideo, .novaInterstitialVerticalVideo, .novaInterstitialHighEngagement:
            return "demo-ios-launch-fullscreen"
        case .facebookNative:
            return "demo-ios-foryou-large"
        case .facebookInterstitial:
            return "demo-ios-launch-fullscreen"
        case .unityBanner:
            return "demo-ios-article-top-unity"
        case .unityInterstitial:
            return "demo-ios-launch-fullscreen-unity"
        case .unityNative:
            return "demo-ios-foryou-large-unity"
        case .clientBiddingBanner:
            return "demo-ios-article-top-client-bidding"
        case .inmobiBanner:
            return "demo-ios-article-top-inmobi"
        case .inmobiInterstitial:
            return "demo-ios-launch-fullscreen-inmobi"
        case .inmobiNative:
            return "demo-ios-foryou-large-inmobi"
        case .mobilefuseBanner:
            return "demo-ios-article-top-mobilefuse"
        case .mobilefuseInterstitial:
            return "demo-ios-launch-fullscreen-mobilefuse"
        case .mobilefuseNative:
            return "demo-ios-foryou-large-mobilefuse"
        case .pubmaticBanner:
            return "demo-ios-article-top-pubmatic"
        case .pubmaticInterstitial:
            return "demo-ios-launch-fullscreen-pubmatic"
        case .pubmaticNative:
            return "demo-ios-foryou-large-pubmatic"
        case .mintegralBanner:
            return "demo-ios-article-top-mintegral"
        case .mintegralInterstitial:
            return "demo-ios-launch-fullscreen-mintegral"
        case .mintegralNative:
            return "demo-ios-foryou-large-mintegral"
        }
    }()
    
    private lazy var adFormat: MSPiOSCore.AdFormat = {
        switch adType {
        case .prebidBanner, .googleBanner, .unityBanner, .inmobiBanner,.pubmaticBanner,.mobilefuseBanner,.mintegralBanner,.clientBiddingBanner :
            return .banner
    
        case .googleNative, .novaNative, .facebookNative, .unityNative, .inmobiNative,.pubmaticNative,.mobilefuseNative,.mintegralNative:
            return .native
        case .googleInterstitial, .novaInterstitialHorizontalImage,.novaInterstitialVerticalImage,.novaInterstitialHorizontalVideo,.novaInterstitialVerticalVideo, .novaInterstitialHighEngagement, .facebookInterstitial, .unityInterstitial, .inmobiInterstitial,.pubmaticInterstitial,.mobilefuseInterstitial,.mintegralInterstitial:
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
        var customParams = [String: Any]()
        var testParams = [String: String]()
        if adType == .novaNative {
            testParams["test"] = "{\"ad_network\":\"msp_nova\",\"test_ad\":true}"
        } else if adType == .novaInterstitialHorizontalImage {
            testParams["test"] = "{\"ad_network\":\"msp_nova\",\"test_ad\":true,\"creative_type\":\"image\",\"is_vertical\":false}"
        } else if adType == .novaInterstitialVerticalImage {
            testParams["test"] = "{\"ad_network\":\"msp_nova\",\"test_ad\":true,\"creative_type\":\"image\",\"is_vertical\":true}"
        } else if adType == .novaInterstitialHorizontalVideo {
            testParams["test"] = "{\"ad_network\":\"msp_nova\",\"test_ad\":true,\"creative_type\":\"video\",\"is_vertical\":false}"
        } else if adType == .novaInterstitialVerticalVideo {
            testParams["test"] = "{\"ad_network\":\"msp_nova\",\"test_ad\":true,\"creative_type\":\"video\",\"is_vertical\":true}"
        } else if adType == .novaInterstitialHighEngagement {
            testParams["test"] = "{\"ad_network\":\"msp_nova\",\"test_ad\":true,\"creative_type\":\"video\",\"is_vertical\":true,\"layout\": \"cancel_top_right\"}"
        } else if adType == .prebidBanner {
            testParams["test"] = "{\"ad_network\":\"pubmatic\",\"test_ad\":true}"
        } else if adType == .googleBanner || adType == .googleInterstitial || adType == .googleNative {
            testParams["test"] = "{\"ad_network\":\"msp_google\",\"test_ad\":true}"
        } else if adType == .facebookNative || adType == .facebookInterstitial {
            testParams["test"] = "{\"ad_network\":\"msp_fb\",\"test_ad\":true}"
        } else if adType == .clientBiddingBanner {
            testParams["test"] = "{\"ad_network\":\"msp_google\",\"test_ad\":true}"
        }
        testParams["mobilefuse"] = "true"
        customParams[MSPConstants.GOOGLE_AD_MULTI_CONTENT_URLS] = ["https://www.google.com", "https://newsbreak.com"]
        
        let adRequest = AdRequest(customParams: customParams,
                                  geo: nil,
                                  context: nil,
                                  adaptiveBannerSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
                                  adSize: AdSize(width: 320, height: 50, isInlineAdaptiveBanner: false, isAnchorAdaptiveBanner: false),
                                  placementId: placementId,
                                  adFormat: adFormat,
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
        print("ad event: on ad dismissed")
    }
    
    func onAdLoaded(placementId: String) {
        if let ad = self.adLoader?.getAd(placementId: placementId) {
            self.onAdLoaded(ad: ad)
        }
    }
    
    func onAdClick(ad: MSPAd) {
        print("ad event: on ad click")
    }
    
    func onAdImpression(ad: MSPAd) {
        print("ad event: on ad impression")
    }
    
    func onAdLoaded(ad: MSPAd) {
        self.ad = ad
        if let priceInDollar = ad.adInfo["price"],
           let priceInDollarValue = priceInDollar as? Double {
            print("demo price: \(priceInDollarValue)")
        }
        if ad is MSPiOSCore.NativeAd,
           let nativeAd = ad as? MSPiOSCore.NativeAd {
            
            DispatchQueue.main.async {
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
            DispatchQueue.main.async{
                let adView = bannerAd.adView
                adView.translatesAutoresizingMaskIntoConstraints = false
                self.view.addSubview(adView)
                NSLayoutConstraint.activate([
                    adView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                    adView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 200),
                    adView.widthAnchor.constraint(equalToConstant: 320),
                    adView.heightAnchor.constraint(equalToConstant: 50)
                ])
            }
        } else if ad is InterstitialAd,
                  let interstitialAd = ad as? InterstitialAd {
            DispatchQueue.main.async {
                interstitialAd.show()
            }
        }
    }
    
    func onError(msg: String) {
        print(msg)
    }
}
