import Foundation
import MSPiOSCore
//import shared
import PrebidAdapter
import PrebidMobile
import UIKit

import SwiftProtobuf

public class MSP {
    
    public static let shared = MSP()
    public var numInitWaitingForCallbacks = 0;
    public var sdkInitListener: MSPInitListener?
    
    public var adNetworkAdapterProvider = MSPAdNetworkAdapterProvider()
    public var bidLoaderProvider = MSPBidLoaderProvider()
    
    public var prebidHost = "https://msp.newsbreak.com"
    public var mesHost = "https://mes-msp.newsbreak.com"
    public var novaEventHost = "https://dsp.newsbreak.com"
    public var org: String?
    public var app: String?
    
    public func initMSP(initParams: InitializationParameters, sdkInitListener: MSPInitListener?) {
        // This is a temporary solution to replace MSPManager class in kotlin to solve the Kotlin singleton issue
        MESMetricReporter.shared.logSDKInit()
        AdCache.shared.adMetricReporter = AdMetricReporterImp()
        if initParams is InitializationParametersImp {
            let params = initParams as? InitializationParametersImp
            self.org = params?.org
            self.app = params?.app
        }
        
        let managers: [AdNetworkManager?] = [adNetworkAdapterProvider.googleManager, adNetworkAdapterProvider.metaManager, adNetworkAdapterProvider.novaManager]
        numInitWaitingForCallbacks = 1 //default vaule is 1 for prebid sdk is alwasys in the dependency
        for adManager in managers {
            if let manager = adManager {
                numInitWaitingForCallbacks += 1
            }
        }
        self.sdkInitListener = sdkInitListener
        var adapterInitListener = MSPAdapterInitListener()
        /*
        fetchServerConfigData { result in
            switch result {
            case .success(let configData):
                if let prebidHost = configData["prebid_host"] {
                    self.prebidHost = prebidHost
                }

                if let mesHost = configData["mes_host"] {
                    self.mesHost = mesHost
                }

                if let novaEventHost = configData["nova_event_host"] {
                    self.novaEventHost = novaEventHost
                }
                
            case .failure(let error):
                print("Error fetching data: \(error)")
            }
            
            self.adNetworkAdapterProvider.googleManager?.getAdNetworkAdapter()?.initialize(initParams: initParams, adapterInitListener: adapterInitListener, context: nil)
            self.adNetworkAdapterProvider.metaManager?.getAdNetworkAdapter()?.initialize(initParams: initParams, adapterInitListener: adapterInitListener, context: nil)
            self.adNetworkAdapterProvider.novaManager?.getAdNetworkAdapter()?.initialize(initParams: initParams, adapterInitListener: adapterInitListener, context: nil)
            PrebidAdapter().initialize(initParams: initParams, adapterInitListener: adapterInitListener, context: nil)
        }
         */
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
    
    func fetchServerConfigData(completion: @escaping (Result<[String: String], Error>) -> Void) {
        let urlString = "https://35.160.18.119/mspconfig"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            // Handle any errors
            if let error = error {
                completion(.failure(error)) // Pass error through completion
                return
            }
            
            // Ensure that we have data
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1, userInfo: nil)))
                return
            }
            
            // Parse the JSON manually using JSONSerialization
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                    completion(.success(json))
                } else {
                    let parsingError = NSError(domain: "Invalid JSON format", code: -2, userInfo: nil)
                    completion(.failure(parsingError))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        // Start the task
        task.resume()
    }
}

public class InitializationParametersImp: InitializationParameters {
    
    public var prebidAPIKey: String
    public var prebidHostUrl: String = MSP.shared.prebidHost + "/openrtb2/auction"
    
    public var sourceApp: String?
    
    public var org: String?
    public var app: String?
    
    public init(prebidAPIKey: String, prebidHostUrl: String, sourceApp: String? = nil) {
        self.prebidAPIKey = prebidAPIKey
        self.prebidHostUrl = prebidHostUrl
        self.sourceApp = sourceApp
    }
    
    public init(prebidAPIKey: String, prebidHostUrl: String, org: String?, app: String?) {
        self.prebidAPIKey = prebidAPIKey
        self.prebidHostUrl = prebidHostUrl
        self.org = org
        self.app = app
    }
    
    public init(prebidAPIKey: String, sourceApp: String? = nil) {
        self.prebidAPIKey = prebidAPIKey
        self.sourceApp = sourceApp
    }
    
    public func getPrebidAPIKey() -> String {
        return prebidAPIKey
    }
    
    public func getPrebidHostUrl() -> String {
        let host = prebidHostUrl ?? MSP.shared.prebidHost + "/openrtb2/auction"
        return host
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
        MESMetricReporter.shared.logAdRequest(adRequest: adRequest)
        self.adListener = adListener
        self.adRequest = adRequest
        
        if adRequest.isCacheSupported, let ad = AdCache.shared.peakAd(placementId: placementId) {
            MESMetricReporter.shared.logAdResult(placementId: placementId, ad: ad, fill: true, isFromCache: true)
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
            adNetworkAdapter?.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
            adNetworkAdapter?.loadAdCreative(bidResponse: bidResponse, adListener: adListener, context: self.rootViewController ?? self, adRequest: adRequest)
        }
    }
    
    public func onError(msg: String) {
        adListener?.onError(msg: msg)
    }
}
