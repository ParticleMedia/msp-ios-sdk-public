//
//  MSPHelper.swift
//  MSPUtility
//
//  Created by Huanzhi Zhang on 1/9/24.
//

import Foundation
import MSPiOSCore
import PrebidAdapter


public class MSPHelper {
    
    public static let shared = MSPHelper()
    public var numInitWaitingForCallbacks = 0;
    public var sdkInitListener: MSPInitListener?
    
    public var adNetworkAdapterProvider = MSPAdNetworkAdapterProvider()
    public var bidLoaderProvider = MSPBidLoaderProvider()
    
    public func initMSP(initParams: InitializationParameters, sdkInitListener: MSPInitListener?) {
        // This is a temporary solution to replace MSPManager class in kotlin to solve the Kotlin singleton issue
        print("msp init SDK")
        numInitWaitingForCallbacks = 2 // For current use case it means 2 adnetwork: prebid, google
        self.sdkInitListener = sdkInitListener
        var adapterInitListener = MSPAdapterInitListener()
        adNetworkAdapterProvider.googleManager?.getAdNetworkAdapter().initialize(initParams: initParams, adapterInitListener: adapterInitListener, context: nil)
        PrebidAdLoader().initialize(initParams: initParams, adapterInitListener: adapterInitListener, context: nil)
    }
    
    public class MSPAdapterInitListener: AdapterInitListener {
        public func onComplete(adNetwork: AdNetwork, adapterInitStatus: AdapterInitStatus, message: String) {
            MSPHelper.shared.numInitWaitingForCallbacks = MSPHelper.shared.numInitWaitingForCallbacks - 1
            if MSPHelper.shared.numInitWaitingForCallbacks == 0{
                MSPHelper.shared.sdkInitListener?.onComplete(status: .success, message: "")
            }
        }
    }
    
    public func setGoogleManager(googleManager: AdNetworkManager) {
        adNetworkAdapterProvider.googleManager = googleManager
    }
}

public class InitializationParametersImp: InitializationParameters {
    
    public var prebidAPIKey: String //= "sggU8Y1UB6xara62G23qGdcOA8co2O4N_debug"
    public var prebidHostUrl: String //= "https://prebid-server.newsbreak.com/openrtb2/auction"
    
    public init(prebidAPIKey: String, prebidHostUrl: String) {
        self.prebidAPIKey = prebidAPIKey
        self.prebidHostUrl = prebidHostUrl
        super.init()
    }
    
    public override func getPrebidAPIKey() -> String {
        return prebidAPIKey
    }
    
    public override func getPrebidHostUrl() -> String {
        return prebidHostUrl
    }
    
    public override func getConsentString() -> String {
        return ""
    }
    
    public override func getParameters() -> [String : Any] {
        return [String : Any]()
    }
    
    public override func hasUserConsent() -> Bool {
        return false
    }
    
    public override func isAgeRestrictedUser() -> Bool {
        return false
    }
    
    public override func isDoNotSell() -> Bool {
        return false
    }
    
    public override func isInTestMode() -> Bool {
        return false
    }
}

public class iOSAdLoader: BidListener {
    var adListener: AdListener?
    var adRequest: AdRequest?
    
    var bidLoader: BidLoader?
    var adNetworkAdapter: AdNetworkAdapter?
    var bidLoaderProvider: BidLoaderProvider?

    var rootViewController: UIViewController?
    
    
    public init() {}
    
    public func loadAd(placementId: String, adListener: AdListener, context: Any, adRequest: AdRequest, rootViewController: UIViewController) {
        
        self.bidLoaderProvider = MSPHelper.shared.bidLoaderProvider
        
        self.adListener = adListener
        self.adRequest = adRequest
        
        self.bidLoader = bidLoaderProvider?.getBidLoader()
        self.rootViewController = rootViewController
        bidLoader?.loadBid(placementId: placementId, adParams: adRequest.customParams, bidListener: self, adRequest: adRequest)
        //loadAd(placementId: placementId, adListener: adListener, context: context, adRequest: adRequest)
    }
    
    public func onBidResponse(bidResponse: Any, adNetwork: AdNetwork) {
        adNetworkAdapter = MSPHelper.shared.adNetworkAdapterProvider.getAdNetworkAdapter(adNetwork: adNetwork)
        if let adListener = self.adListener,
           let adRequest = self.adRequest {
            adNetworkAdapter?.loadAdCreative(bidResponse: bidResponse, adListener: adListener, context: self.rootViewController ?? self, adRequest: adRequest)
        }
    }
    
    public func onError(msg: String) {
        adListener?.onError(msg: msg)
    }
}
