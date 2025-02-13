import Foundation
import AdSupport
import MSPiOSCore
//import shared
import PrebidAdapter
import PrebidMobile
import UIKit
import AppTrackingTransparency

import SwiftProtobuf

public class MSP {
    
    public static let shared = MSP()
    public var numInitWaitingForCallbacks = 0;
    public weak var sdkInitListener: MSPInitListener?
    
    public var adNetworkAdapterProvider = MSPAdNetworkAdapterProvider()
    public var bidLoaderProvider = MSPBidLoaderProvider()
    
    public var prebidHost = "https://msp.newsbreak.com"
    public var mesHost = "https://mes-msp.newsbreak.com"
    public var novaEventHost = "https://dsp.newsbreak.com"
    public var orgId: Int64?
    public var appId: Int64?
    public var org: String?
    public var app: String?
    public var ppid: String?
    public var email: String?
    public var prebidAPIKey: String?
    
    public func initMSP(initParams: InitializationParameters, sdkInitListener: MSPInitListener?, adNetworkManagers: [AdNetworkManager]) {
        // This is a temporary solution to replace MSPManager class in kotlin to solve the Kotlin singleton issue
        MESMetricReporter.shared.logSDKInit()
        AdCache.shared.adMetricReporter = AdMetricReporterImp()
        if initParams is InitializationParametersImp {
            let params = initParams as? InitializationParametersImp
            self.orgId = params?.orgId
            self.appId = params?.appId
            if let orgId = orgId {
                self.org = String(orgId)
            }
            if let appId = appId {
                self.app = String(appId)
            }
            self.prebidAPIKey = initParams.getPrebidAPIKey()
        }
        
        if UserDefaults.standard.string(forKey: "msp_user_id") == nil {
            fetchMSPUserId()
        }
        
        numInitWaitingForCallbacks = 1 //default vaule is 1 for prebid sdk is alwasys in the dependency
        for manager in adNetworkManagers {
            if let adNetworkAdapter = manager.getAdNetworkAdapter() {
                adNetworkAdapterProvider.adNetworkManagerDict[adNetworkAdapter.getAdNetwork()] = manager
                numInitWaitingForCallbacks += 1
            }
            
        }
        self.sdkInitListener = sdkInitListener
        var adapterInitListener = MSPAdapterInitListener()
        
        MSPAdConfigManager.shared.initAdConfig()
        for manager in adNetworkManagers {
            if let adNetworkAdapter = manager.getAdNetworkAdapter() {
                adNetworkAdapter.initialize(initParams: initParams, adapterInitListener: adapterInitListener, context: nil)
            }
        }
        PrebidAdapter.initializePrebid(initParams: initParams, adapterInitListener: adapterInitListener, context: nil)
       
        if let initParamsImp = initParams as? InitializationParametersImp,
           let sourceApp = initParamsImp.sourceApp {
            Targeting.shared.sourceapp = sourceApp
        }
        Prebid.shared.shareGeoLocation = true
        
        UserDefaults.standard.setValue(String(Date().timeIntervalSince1970 * 1000), forKey: "FirstLaunchTime")
    }
    
    public class MSPAdapterInitListener: NSObject, AdapterInitListener {
        public func onComplete(adNetwork: AdNetwork, adapterInitStatus: AdapterInitStatus, message: String) {
            MSP.shared.numInitWaitingForCallbacks = MSP.shared.numInitWaitingForCallbacks - 1
            if MSP.shared.numInitWaitingForCallbacks == 0 {
                MSP.shared.sdkInitListener?.onComplete(status: .SUCCESS, message: "")
            }
        }
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
    
    func fetchMSPUserId() {
        guard let url = URL(string: "https://id-msp.newsbreak.com/getId") else {
            return
        }
        let parameters: [String: Any] = [
            "orgID": self.orgId ?? 0,
            "appID": self.appId ?? 0,
            "ppid": self.ppid ?? "",
            "device_id": ASIdentifierManager.shared().advertisingIdentifier.uuidString ?? "",
            "email": self.email ?? "",
            "token": self.prebidAPIKey ?? ""
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: []) else {
            print("Error: Cannot serialize parameters")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let data = data {
                    do {
                        // Handle JSON response
                        if let responseDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                           let id = responseDict["id"] as? Int64 {
                            UserDefaults.standard.setValue(String(id), forKey: "msp_user_id")
                        }
                    } catch {
                        print("Error parsing response: \(error)")
                    }
                }
            } else {
                print("Unexpected response code or data")
            }
        }
        
        task.resume()

    }
    
}

public class InitializationParametersImp: InitializationParameters {
    
    public var prebidAPIKey: String
    public var prebidHostUrl: String = MSP.shared.prebidHost + "/openrtb2/auction"
    
    public var sourceApp: String?
    
    public var orgId: Int64?
    public var appId: Int64?
    
    public var params: [String: Any]?
    
    public init(prebidAPIKey: String, prebidHostUrl: String, sourceApp: String? = nil) {
        self.prebidAPIKey = prebidAPIKey
        self.prebidHostUrl = prebidHostUrl
        self.sourceApp = sourceApp
    }
    
    public init(prebidAPIKey: String, prebidHostUrl: String, orgId: Int64?, appId: Int64?) {
        self.prebidAPIKey = prebidAPIKey
        self.prebidHostUrl = prebidHostUrl
        self.orgId = orgId
        self.appId = appId
    }
    
    public init(prebidAPIKey: String, sourceApp: String?, orgId: Int64?, appId: Int64?) {
        self.prebidAPIKey = prebidAPIKey
        self.sourceApp = sourceApp
        self.orgId = orgId
        self.appId = appId
    }
    
    public init(prebidAPIKey: String, sourceApp: String? = nil) {
        self.prebidAPIKey = prebidAPIKey
        self.sourceApp = sourceApp
    }
    
    public init(prebidAPIKey: String, orgId: Int64?, appId: Int64?) {
        self.prebidAPIKey = prebidAPIKey
        self.orgId = orgId
        self.appId = appId
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
        return params
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
