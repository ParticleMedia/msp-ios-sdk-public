//
//  AmazonAdapter.swift
//  AmazonAdapter
//
//  Created by Huanzhi Zhang on 8/8/25.
//
import MSPiOSCore
import MSPGoogleAdsTypes
import Foundation
import DTBiOSSDK

@objc public class AmazonAdapter : NSObject, AdNetworkAdapter {
    private var dtbAdLoader: DTBAdLoader?
    private var dtbAdResponse: DTBAdResponse?
    
    private var bannerView: MSPGAMBannerView?
    public weak var auctionBidListener: AuctionBidListener?
    public var bidderPlacementId: String?
    public var googlePlacementId: String? // placement id used in google banner view
    private var dtbAdSize: DTBAdSize?

    public var adRequest: AdRequest?
    private var adMetricReporter: AdMetricReporter?
    
    private var bannerAd: BannerAd?
    
    public weak var adListener: AdListener?
    public var priceInDollar: Double?
    
    public func loadAdCreative(bidResponse: Any, auctionBidListener: any MSPiOSCore.AuctionBidListener, adListener: any MSPiOSCore.AdListener, context: Any, adRequest: MSPiOSCore.AdRequest, bidderPlacementId: String, bidderFormat: MSPiOSCore.AdFormat?, params: [String : String]?) {
        self.adListener = adListener
        self.auctionBidListener = auctionBidListener
        self.bidderPlacementId = bidderPlacementId
        self.adRequest = adRequest
        if let params = params,
           let googlePlacementId = params["googlePlacementId"] {
            self.googlePlacementId = googlePlacementId
        }
        let dtbAdLoader = DTBAdLoader()
        self.dtbAdLoader = dtbAdLoader
        let dtbAdSize = DTBAdSize(bannerAdSizeWithWidth: adRequest.adSize?.width ?? 320, height: adRequest.adSize?.height ?? 50, andSlotUUID: bidderPlacementId)
        self.dtbAdSize = dtbAdSize
        dtbAdLoader.setAdSizes([dtbAdSize])
        dtbAdLoader.loadAd(self)
    }
    
    public func initialize(initParams: any MSPiOSCore.InitializationParameters, adapterInitListener: any MSPiOSCore.AdapterInitListener, context: Any?) {
        if let params = initParams.getParameters(),
           let appKey = params[InitializationParametersCustomKeys.AMAZON_APP_KEY] as? String {
            DTBAds.sharedInstance().setAppKey(appKey)
        }
        DTBAds.sharedInstance().mraidPolicy = CUSTOM_MRAID
        DTBAds.sharedInstance().mraidCustomVersions = ["1.0", "2.0", "3.0"]
        DTBAds.sharedInstance().useGeoLocation = true
        adapterInitListener.onComplete(adNetwork: .amazon, adapterInitStatus: .SUCCESS, message: "")
    }
    
    public func destroyAd() {
        
    }
    
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        
    }
    
    public func setAdMetricReporter(adMetricReporter: any MSPiOSCore.AdMetricReporter) {
        self.adMetricReporter = adMetricReporter
    }
    
    public func getAdNetwork() -> MSPiOSCore.AdNetwork {
        return .amazon
    }
    
    public func sendHideAdEvent(reason: String, adScreenShot: Data?, fullScreenShot: Data?)
    {
        if let adRequest = self.adRequest,
           let ad = self.bannerAd {
            self.adMetricReporter?.logAdHide(ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, adScreenShot: adScreenShot, fullScreenShot: fullScreenShot)
        }
    }
    
    public func sendReportAdEvent(reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?) {
        if let adRequest = self.adRequest,
           let ad = self.bannerAd {
            self.adMetricReporter?.logAdReport(ad: ad, adRequest: adRequest, bidResponse: self, reason: reason, description: description, adScreenShot: adScreenShot, fullScreenShot: fullScreenShot)
        }
    }
    
    public func getSDKVersion() -> String {
        return "1.0.1-rc.9"
    }
    
    public func sendClickAdEvent(ad: MSPAd) {
        if let adRequest = adRequest {
            self.adMetricReporter?.logAdClick(ad: ad, adRequest: adRequest, bidResponse: self)
        }
    }
    private static let amazonPriceMap = [
        "m320x50p220": 2.20,
        "m320x50p221": 2.21,
        "m320x50p222": 2.22,
        "m320x50p223": 2.23,
        "m320x50p224": 2.24,
        "m320x50p225": 2.25,
        "m320x50p226": 2.26,
        "m320x50p227": 2.27,
        "m320x50p228": 2.28,
        "m320x50p229": 2.29,
        "m320x50p230": 2.30,
        "m320x50p231": 2.31,
        "m320x50p232": 2.32,
        "m320x50p233": 2.33,
        "m320x50p234": 2.34,
        "m320x50p235": 2.35,
        "m320x50p236": 2.36,
        "m320x50p237": 2.37,
        "m320x50p238": 2.38,
        "m320x50p239": 2.39,
        "m320x50p240": 2.40,
        "m320x50p241": 2.41,
        "m320x50p242": 2.42,
        "m320x50p243": 2.43,
        "m320x50p244": 2.44,
        "m320x50p245": 2.45,
        "m320x50p246": 2.46,
        "m320x50p247": 2.47,
        "m320x50p248": 2.48,
        "m320x50p249": 2.49,
        "m320x50p250": 2.50,
        "m320x50p251": 2.51,
        "m320x50p252": 2.52,
        "m320x50p253": 2.53,
        "m320x50p254": 2.54,
        "m320x50p255": 2.55,
        "m320x50p256": 2.56,
        "m320x50p257": 2.57,
        "m320x50p258": 2.58,
        "m320x50p259": 2.59,
        "m320x50p260": 2.60,
        "m320x50p261": 2.61,
        "m320x50p262": 2.62,
        "m320x50p263": 2.63,
        "m320x50p264": 2.64,
        "m320x50p265": 2.65,
        "m320x50p266": 2.66,
        "m320x50p267": 2.67,
        "m320x50p268": 2.68,
        "m320x50p269": 2.69,
        "m320x50p270": 2.70,
        "m320x50p271": 2.71,
        "m320x50p272": 2.72,
        "m320x50p273": 2.73,
        "m320x50p274": 2.74,
        "m320x50p275": 2.75,
        "m320x50p276": 2.76,
        "m320x50p277": 2.77,
        "m320x50p278": 2.78,
        "m320x50p279": 2.79,
        "m320x50p280": 2.80,
        "m320x50p281": 2.81,
        "m320x50p282": 2.82,
        "m320x50p283": 2.83,
        "m320x50p284": 2.84,
        "m320x50p285": 2.85,
        "m320x50p286": 2.86,
        "m320x50p287": 2.87,
        "m320x50p288": 2.88,
        "m320x50p289": 2.89,
        "m320x50p290": 2.90,
        "m320x50p291": 2.91,
        "m320x50p292": 2.92,
        "m320x50p293": 2.93,
        "m320x50p294": 2.94,
        "m320x50p295": 2.95,
        "m320x50p296": 2.96,
        "m320x50p297": 2.97,
        "m320x50p298": 2.98,
        "m320x50p299": 2.99,
        "m320x50p300": 3.00,
        "m320x50p301": 3.05,
        "m320x50p302": 3.1,
        "m320x50p303": 3.15,
        "m320x50p304": 3.2,
        "m320x50p305": 3.25,
        "m320x50p306": 3.3,
        "m320x50p307": 3.35,
        "m320x50p308": 3.4,
        "m320x50p309": 3.45,
        "m320x50p310": 3.5,
        "m320x50p311": 3.55,
        "m320x50p312": 3.6,
        "m320x50p313": 3.65,
        "m320x50p314": 3.7,
        "m320x50p315": 3.75,
        "m320x50p316": 3.8,
        "m320x50p317": 3.85,
        "m320x50p318": 3.9,
        "m320x50p319": 3.95,
        "m320x50p320": 4,
        "m320x50p321": 4.05,
        "m320x50p322": 4.1,
        "m320x50p323": 4.15,
        "m320x50p324": 4.2,
        "m320x50p325": 4.25,
        "m320x50p326": 4.3,
        "m320x50p327": 4.35,
        "m320x50p328": 4.4,
        "m320x50p329": 4.45,
        "m320x50p330": 4.5,
        "m320x50p331": 4.55,
        "m320x50p332": 4.6,
        "m320x50p333": 4.65,
        "m320x50p334": 4.7,
        "m320x50p335": 4.75,
        "m320x50p336": 4.8,
        "m320x50p337": 4.85,
        "m320x50p338": 4.9,
        "m320x50p339": 4.95,
        "m320x50p340": 5,
        "m320x50p341": 5.05,
        "m320x50p342": 5.1,
        "m320x50p343": 5.15,
        "m320x50p344": 5.2,
        "m320x50p345": 5.25,
        "m320x50p346": 5.3,
        "m320x50p347": 5.35,
        "m320x50p348": 5.4,
        "m320x50p349": 5.45,
        "m320x50p350": 5.5,
        "m320x50p351": 5.55,
        "m320x50p352": 5.6,
        "m320x50p353": 5.65,
        "m320x50p354": 5.7,
        "m320x50p355": 5.75,
        "m320x50p356": 5.8,
        "m320x50p357": 5.85,
        "m320x50p358": 5.9,
        "m320x50p359": 5.95,
        "m320x50p360": 6,
        "m320x50p361": 6.05,
        "m320x50p362": 6.1,
        "m320x50p363": 6.15,
        "m320x50p364": 6.2,
        "m320x50p365": 6.25,
        "m320x50p366": 6.3,
        "m320x50p367": 6.35,
        "m320x50p368": 6.4,
        "m320x50p369": 6.45,
        "m320x50p370": 6.5,
        "m320x50p371": 6.55,
        "m320x50p372": 6.6,
        "m320x50p373": 6.65,
        "m320x50p374": 6.7,
        "m320x50p375": 6.75,
        "m320x50p376": 6.8,
        "m320x50p377": 6.85,
        "m320x50p378": 6.9,
        "m320x50p379": 6.95,
        "m320x50p380": 7,
        "m320x50p381": 7.05,
        "m320x50p382": 7.1,
        "m320x50p383": 7.15,
        "m320x50p384": 7.2,
        "m320x50p385": 7.25,
        "m320x50p386": 7.3,
        "m320x50p387": 7.35,
        "m320x50p388": 7.4,
        "m320x50p389": 7.45,
        "m320x50p390": 7.5,
        "m320x50p391": 7.55,
        "m320x50p392": 7.6,
        "m320x50p393": 7.65,
        "m320x50p394": 7.7,
        "m320x50p395": 7.75,
        "m320x50p396": 7.8,
        "m320x50p397": 7.85,
        "m320x50p398": 7.9,
        "m320x50p399": 7.95,
        "m320x50p400": 8,
        "m320x50p401": 8.5,
        "m320x50p402": 9,
        "m320x50p403": 9.5,
        "m320x50p404": 10,
        "m320x50p405": 10.5,
        "m320x50p406": 11,
        "m320x50p407": 11.5,
        "m320x50p408": 12,
        "m320x50p409": 12.5,
        "m320x50p410": 13,
        "m320x50p411": 13.5,
        "m320x50p412": 14,
        "m320x50p413": 14.5,
        "m320x50p414": 15,
        "m320x50p415": 15.5,
        "m320x50p416": 16,
        "m320x50p417": 16.5,
        "m320x50p418": 17,
        "m320x50p419": 17.5,
        "m320x50p420": 18,
        "m320x50p421": 18.5,
        "m320x50p422": 19,
        "m320x50p423": 19.5,
        "m320x50p424": 20,
        "m320x50p425": 21,
        "m320x50p426": 22,
        "m320x50p427": 23,
        "m320x50p428": 24,
        "m320x50p429": 25,
        "m320x50p430": 26,
        "m320x50p431": 27,
        "m320x50p432": 28,
        "m320x50p433": 29,
        "m320x50p434": 30,
        "m320x50p435": 31,
        "m320x50p436": 32,
        "m320x50p437": 33,
        "m320x50p438": 34,
        "m320x50p439": 35,

        "m300x250p220": 2.2,
        "m300x250p221": 2.21,
        "m300x250p222": 2.22,
        "m300x250p223": 2.23,
        "m300x250p224": 2.24,
        "m300x250p225": 2.25,
        "m300x250p226": 2.26,
        "m300x250p227": 2.27,
        "m300x250p228": 2.28,
        "m300x250p229": 2.29,
        "m300x250p230": 2.3,
        "m300x250p231": 2.31,
        "m300x250p232": 2.32,
        "m300x250p233": 2.33,
        "m300x250p234": 2.34,
        "m300x250p235": 2.35,
        "m300x250p236": 2.36,
        "m300x250p237": 2.37,
        "m300x250p238": 2.38,
        "m300x250p239": 2.39,
        "m300x250p240": 2.4,
        "m300x250p241": 2.41,
        "m300x250p242": 2.42,
        "m300x250p243": 2.43,
        "m300x250p244": 2.44,
        "m300x250p245": 2.45,
        "m300x250p246": 2.46,
        "m300x250p247": 2.47,
        "m300x250p248": 2.48,
        "m300x250p249": 2.49,
        "m300x250p250": 2.5,
        "m300x250p251": 2.51,
        "m300x250p252": 2.52,
        "m300x250p253": 2.53,
        "m300x250p254": 2.54,
        "m300x250p255": 2.55,
        "m300x250p256": 2.56,
        "m300x250p257": 2.57,
        "m300x250p258": 2.58,
        "m300x250p259": 2.59,
        "m300x250p260": 2.6,
        "m300x250p261": 2.61,
        "m300x250p262": 2.62,
        "m300x250p263": 2.63,
        "m300x250p264": 2.64,
        "m300x250p265": 2.65,
        "m300x250p266": 2.66,
        "m300x250p267": 2.67,
        "m300x250p268": 2.68,
        "m300x250p269": 2.69,
        "m300x250p270": 2.7,
        "m300x250p271": 2.71,
        "m300x250p272": 2.72,
        "m300x250p273": 2.73,
        "m300x250p274": 2.74,
        "m300x250p275": 2.75,
        "m300x250p276": 2.76,
        "m300x250p277": 2.77,
        "m300x250p278": 2.78,
        "m300x250p279": 2.79,
        "m300x250p280": 2.8,
        "m300x250p281": 2.81,
        "m300x250p282": 2.82,
        "m300x250p283": 2.83,
        "m300x250p284": 2.84,
        "m300x250p285": 2.85,
        "m300x250p286": 2.86,
        "m300x250p287": 2.87,
        "m300x250p288": 2.88,
        "m300x250p289": 2.89,
        "m300x250p290": 2.9,
        "m300x250p291": 2.91,
        "m300x250p292": 2.92,
        "m300x250p293": 2.93,
        "m300x250p294": 2.94,
        "m300x250p295": 2.95,
        "m300x250p296": 2.96,
        "m300x250p297": 2.97,
        "m300x250p298": 2.98,
        "m300x250p299": 2.99,
        "m300x250p300": 3,
        "m300x250p301": 3.05,
        "m300x250p302": 3.1,
        "m300x250p303": 3.15,
        "m300x250p304": 3.2,
        "m300x250p305": 3.25,
        "m300x250p306": 3.3,
        "m300x250p307": 3.35,
        "m300x250p308": 3.4,
        "m300x250p309": 3.45,
        "m300x250p310": 3.5,
        "m300x250p311": 3.55,
        "m300x250p312": 3.6,
        "m300x250p313": 3.65,
        "m300x250p314": 3.7,
        "m300x250p315": 3.75,
        "m300x250p316": 3.8,
        "m300x250p317": 3.85,
        "m300x250p318": 3.9,
        "m300x250p319": 3.95,
        "m300x250p320": 4,
        "m300x250p321": 4.05,
        "m300x250p322": 4.1,
        "m300x250p323": 4.15,
        "m300x250p324": 4.2,
        "m300x250p325": 4.25,
        "m300x250p326": 4.3,
        "m300x250p327": 4.35,
        "m300x250p328": 4.4,
        "m300x250p329": 4.45,
        "m300x250p330": 4.5,
        "m300x250p331": 4.55,
        "m300x250p332": 4.6,
        "m300x250p333": 4.65,
        "m300x250p334": 4.7,
        "m300x250p335": 4.75,
        "m300x250p336": 4.8,
        "m300x250p337": 4.85,
        "m300x250p338": 4.9,
        "m300x250p339": 4.95,
        "m300x250p340": 5,
        "m300x250p341": 5.05,
        "m300x250p342": 5.1,
        "m300x250p343": 5.15,
        "m300x250p344": 5.2,
        "m300x250p345": 5.25,
        "m300x250p346": 5.3,
        "m300x250p347": 5.35,
        "m300x250p348": 5.4,
        "m300x250p349": 5.45,
        "m300x250p350": 5.5,
        "m300x250p351": 5.55,
        "m300x250p352": 5.6,
        "m300x250p353": 5.65,
        "m300x250p354": 5.7,
        "m300x250p355": 5.75,
        "m300x250p356": 5.8,
        "m300x250p357": 5.85,
        "m300x250p358": 5.9,
        "m300x250p359": 5.95,
        "m300x250p360": 6,
        "m300x250p361": 6.05,
        "m300x250p362": 6.1,
        "m300x250p363": 6.15,
        "m300x250p364": 6.2,
        "m300x250p365": 6.25,
        "m300x250p366": 6.3,
        "m300x250p367": 6.35,
        "m300x250p368": 6.4,
        "m300x250p369": 6.45,
        "m300x250p370": 6.5,
        "m300x250p371": 6.55,
        "m300x250p372": 6.6,
        "m300x250p373": 6.65,
        "m300x250p374": 6.7,
        "m300x250p375": 6.75,
        "m300x250p376": 6.8,
        "m300x250p377": 6.85,
        "m300x250p378": 6.9,
        "m300x250p379": 6.95,
        "m300x250p380": 7,
        "m300x250p381": 7.05,
        "m300x250p382": 7.1,
        "m300x250p383": 7.15,
        "m300x250p384": 7.2,
        "m300x250p385": 7.25,
        "m300x250p386": 7.3,
        "m300x250p387": 7.35,
        "m300x250p388": 7.4,
        "m300x250p389": 7.45,
        "m300x250p390": 7.5,
        "m300x250p391": 7.55,
        "m300x250p392": 7.6,
        "m300x250p393": 7.65,
        "m300x250p394": 7.7,
        "m300x250p395": 7.75,
        "m300x250p396": 7.8,
        "m300x250p397": 7.85,
        "m300x250p398": 7.9,
        "m300x250p399": 7.95,
        "m300x250p400": 8,
        "m300x250p401": 8.5,
        "m300x250p402": 9,
        "m300x250p403": 9.5,
        "m300x250p404": 10,
        "m300x250p405": 10.5,
        "m300x250p406": 11,
        "m300x250p407": 11.5,
        "m300x250p408": 12,
        "m300x250p409": 12.5,
        "m300x250p410": 13,
        "m300x250p411": 13.5,
        "m300x250p412": 14,
        "m300x250p413": 14.5,
        "m300x250p414": 15,
        "m300x250p415": 15.5,
        "m300x250p416": 16,
        "m300x250p417": 16.5,
        "m300x250p418": 17,
        "m300x250p419": 17.5,
        "m300x250p420": 18,
        "m300x250p421": 18.5,
        "m300x250p422": 19,
        "m300x250p423": 19.5,
        "m300x250p424": 20,
        "m300x250p425": 21,
        "m300x250p426": 22,
        "m300x250p427": 23,
        "m300x250p428": 24,
        "m300x250p429": 25,
        "m300x250p430": 26,
        "m300x250p431": 27,
        "m300x250p432": 28,
        "m300x250p433": 29,
        "m300x250p434": 30,
        "m300x250p435": 31,
        "m300x250p436": 32,
        "m300x250p437": 33,
        "m300x250p438": 34,
        "m300x250p439": 35,
    ]
}

extension AmazonAdapter: DTBAdCallback {
    public func onSuccess(_ adResponse: DTBAdResponse!) {
        
        self.dtbAdResponse = adResponse
        let bannerView = MSPGAMBannerView(adSize: getGADAdSize())
        self.bannerView = bannerView
        if let dtbAdSize = self.dtbAdSize,
           let pricePoint = adResponse.pricePoints(dtbAdSize){
            let priceInDollar = AmazonAdapter.amazonPriceMap[pricePoint]
            self.priceInDollar = priceInDollar
        }
        bannerView.adUnitID = self.googlePlacementId
        bannerView.rootViewController = self.adListener?.getRootViewController()
        bannerView.delegate = self
        let gamRequest = MSPGADRequest()
        gamRequest.customTargeting = adResponse.customTargeting()
        bannerView.load(gamRequest)
        
    }
    
    public func onFailure(_ error: DTBAdError) {
        MSPLogger.shared.info(message: "[Adapter: Amazon] Fail to receive ad")
        self.auctionBidListener?.onError(error: String(error.rawValue))
        self.adMetricReporter?.logAdResult(placementId: adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR, errorMessage: String(error.rawValue))
        }
    }
    
    func getGADAdSize() -> MSPGADAdSize {
        if let adRequest = adRequest {
            if let width = adRequest.adSize?.width,
               let height = adRequest.adSize?.height {
                if width == 300, height == 250 {
                    return MSPGADAdSizeMediumRectangle
                }
            }
        }
        return MSPGADAdSizeBanner
    }
    
}
extension AmazonAdapter: MSPGADBannerViewDelegate {
    public func bannerViewDidReceiveAd(_ bannerView: MSPGADBannerView) {
        MSPLogger.shared.info(message: "[Adapter: Amazon] successfully loaded Google Banner ad")
        DispatchQueue.main.async {
            var bannerAd = BannerAd(adView: bannerView, adNetworkAdapter: self)
            self.bannerAd = bannerAd
            if let priceInDollar = self.priceInDollar {
                bannerAd.adInfo[MSPConstants.AD_INFO_PRICE] = priceInDollar
            }
            
            bannerAd.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] = AdNetwork.amazon.rawValue
            bannerAd.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] = self.bidderPlacementId
            if let adListener = self.adListener,
               let adRequest = self.adRequest,
               let auctionBidListener = self.auctionBidListener {
                //handleAdLoaded(ad: bannerAd, listener: adListener, adRequest: adRequest)
                self.handleAdLoaded(ad: bannerAd, auctionBidListener: auctionBidListener, bidderPlacementId: self.bidderPlacementId ?? adRequest.placementId)
                self.adMetricReporter?.logAdResult(placementId: adRequest.placementId, ad: bannerAd, fill: true, isFromCache: false)
            }
        }
    }
    
    public func bannerView(_ bannerView: MSPGADBannerView, didFailToReceiveAdWithError error: Error) {
        MSPLogger.shared.info(message: "[Adapter: Amazon] Fail to load Google Banner ad")
        self.auctionBidListener?.onError(error: error.localizedDescription)
        self.adMetricReporter?.logAdResult(placementId: adRequest?.placementId ?? "", ad: nil, fill: false, isFromCache: false)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(ad: nil, adRequest: adRequest, errorCode: .ERROR_CODE_INTERNAL_ERROR, errorMessage: error.localizedDescription)
        }
    }
    
    public func bannerViewDidRecordClick(_ bannerView: MSPGADBannerView) {
        if let googleAd = self.bannerAd {
            self.adListener?.onAdClick(ad: googleAd)
            self.sendClickAdEvent(ad: googleAd)
        }
    }
    
    public func bannerViewDidRecordImpression(_ bannerView: MSPGADBannerView) {
        if let googleAd = self.bannerAd {
            self.adListener?.onAdImpression(ad: googleAd)
            if let adRequest = adRequest {
                self.adMetricReporter?.logAdImpression(ad: googleAd, adRequest: adRequest, bidResponse: self)
            }
        }
    }
    
    public func handleAdLoaded(ad: MSPAd, auctionBidListener: AuctionBidListener, bidderPlacementId: String) {
        // to do: move this to ios core
        AdCache.shared.saveAd(placementId: bidderPlacementId, ad: ad)
        let auctionBid = AuctionBid(bidderName: "msp", bidderPlacementId: bidderPlacementId, ecpm: ad.adInfo["price"] as? Double ?? 0.0)
        auctionBidListener.onSuccess(bid: auctionBid)
        if let adRequest = self.adRequest {
            self.adMetricReporter?.logAdResponse(ad: ad, adRequest: adRequest, errorCode: .ERROR_CODE_SUCCESS, errorMessage: nil)
        }
    }
}
