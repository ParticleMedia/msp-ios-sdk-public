import Foundation
import MSPiOSCore
//import shared
import PrebidAdapter
import PrebidMobile
import UIKit

public class MSP {
    
    public static let shared = MSP()
    public var numInitWaitingForCallbacks = 0;
    public var sdkInitListener: MSPInitListener?
    
    public var adNetworkAdapterProvider = MSPAdNetworkAdapterProvider()
    public var bidLoaderProvider = MSPBidLoaderProvider()
    
    public func initMSP(initParams: InitializationParameters, sdkInitListener: MSPInitListener?) {
        // This is a temporary solution to replace MSPManager class in kotlin to solve the Kotlin singleton issue
        let managers: [AdNetworkManager?] = [adNetworkAdapterProvider.googleManager, adNetworkAdapterProvider.metaManager, adNetworkAdapterProvider.novaManager]
        numInitWaitingForCallbacks = 1 //default vaule is 1 for prebid sdk is alwasys in the dependency
        for adManager in managers {
            if let manager = adManager {
                numInitWaitingForCallbacks += 1
            }
        }
        self.sdkInitListener = sdkInitListener
        var adapterInitListener = MSPAdapterInitListener()
        adNetworkAdapterProvider.googleManager?.getAdNetworkAdapter()?.initialize(initParams: initParams, adapterInitListener: adapterInitListener, context: nil)
        adNetworkAdapterProvider.metaManager?.getAdNetworkAdapter()?.initialize(initParams: initParams, adapterInitListener: adapterInitListener, context: nil)
        adNetworkAdapterProvider.novaManager?.getAdNetworkAdapter()?.initialize(initParams: initParams, adapterInitListener: adapterInitListener, context: nil)
        PrebidAdapter().initialize(initParams: initParams, adapterInitListener: adapterInitListener, context: nil)
        
        if let initParamsImp = initParams as? InitializationParametersImp,
           let sourceApp = initParamsImp.sourceApp {
            Targeting.shared.sourceapp = sourceApp
        }
        Prebid.shared.shareGeoLocation = true
        
        UserDefaults.standard.setValue(String(Date().timeIntervalSince1970 * 1000), forKey: "FirstLaunchTime")
    }
    
    public class MSPAdapterInitListener: AdapterInitListener {
        public func onComplete(adNetwork: AdNetwork, adapterInitStatus: AdapterInitStatus, message: String) {
            MSP.shared.numInitWaitingForCallbacks = MSP.shared.numInitWaitingForCallbacks - 1
            if MSP.shared.numInitWaitingForCallbacks == 0 {
                MSP.shared.sdkInitListener?.onComplete(status: .SUCCESS, message: "")
            }
        }
    }
    
    public func setGoogleManager(googleManager: AdNetworkManager) {
        adNetworkAdapterProvider.googleManager = googleManager
    }
    
    public func setNovaManager(novaManager: AdNetworkManager) {
        adNetworkAdapterProvider.novaManager = novaManager
    }
    
    public func setMetaManager(metaManager: AdNetworkManager) {
        adNetworkAdapterProvider.metaManager = metaManager
    }
}

public class InitializationParametersImp: InitializationParameters {
    
    public var prebidAPIKey: String //= "sggU8Y1UB6xara62G23qGdcOA8co2O4N_debug"
    public var prebidHostUrl: String //= "https://prebid-server.newsbreak.com/openrtb2/auction"
    
    public var sourceApp: String?
    
    public init(prebidAPIKey: String, prebidHostUrl: String, sourceApp: String? = nil) {
        self.prebidAPIKey = prebidAPIKey
        self.prebidHostUrl = prebidHostUrl
        self.sourceApp = sourceApp
    }
    
    public func getPrebidAPIKey() -> String {
        return prebidAPIKey
    }
    
    public func getPrebidHostUrl() -> String {
        return prebidHostUrl
    }
    
    public func getConsentString() -> String {
        return ""
    }
    
    public func getParameters() -> [String : Any]? {
        return [String : Any]()
    }
    
    public func hasUserConsent() -> Bool {
        return false
    }
    
    public func isAgeRestrictedUser() -> Bool {
        return false
    }
    
    public func isDoNotSell() -> Bool {
        return false
    }
    
    public func isInTestMode() -> Bool {
        return false
    }
}

public class MSPAdLoader: BidListener {
    var adListener: AdListener?
    var adRequest: AdRequest?
    
    weak var bidLoader: BidLoader?
    var adNetworkAdapter: AdNetworkAdapter?

    var rootViewController: UIViewController?
    
    
    public init() {}
    
    public func loadAd(placementId: String, adListener: AdListener, context: Any, adRequest: AdRequest, rootViewController: UIViewController) {
        
        self.adListener = adListener
        self.adRequest = adRequest
        
        if adRequest.isCacheSupported, let ad = AdCache.shared.peakAd(placementId: placementId) {
            adListener.onAdLoaded(placementId: placementId)
            return
        }
        
        self.bidLoader = MSP.shared.bidLoaderProvider.getBidLoader()
        self.rootViewController = rootViewController
        bidLoader?.loadBid(placementId: placementId, adParams: adRequest.customParams, bidListener: self, adRequest: adRequest)
    }
    
    public func onBidResponse(bidResponse: Any, adNetwork: AdNetwork) {
        adNetworkAdapter = MSP.shared.adNetworkAdapterProvider.getAdNetworkAdapter(adNetwork: adNetwork)
        if let adListener = self.adListener,
           let adRequest = self.adRequest {
            adNetworkAdapter?.loadAdCreative(bidResponse: bidResponse, adListener: adListener, context: self.rootViewController ?? self, adRequest: adRequest)
        }
    }
    
    public func onError(msg: String) {
        adListener?.onError(msg: msg)
    }
}
