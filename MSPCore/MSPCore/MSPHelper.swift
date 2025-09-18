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
    public let version = "" // please config version number in release branch
    
    public static let shared = MSP()
    public var numInitWaitingForCallbacks = 0;
    public weak var sdkInitListener: MSPInitListener?
    public var initStartTime: Double?
    public var adNetworkInitStartTime: [String: Double] = [:]
    public var adNetworkInitLatencyInMs: [String: Int32] = [:]
    public var blockLatencyInMs: Int32?
    
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

    public var isLogSampled = false
    public var logWhiteList: [String]?
    
    public func initMSP(initParams: InitializationParameters, sdkInitListener: MSPInitListener?, adNetworkManagers: [AdNetworkManager]) {
        // This is a temporary solution to replace MSPManager class in kotlin to solve the Kotlin singleton issue
        DispatchQueue.main.async {
            let initStartTime = Date().timeIntervalSince1970
            self.initStartTime = initStartTime
            AdCache.shared.adMetricReporter = AdMetricReporterImp()
            if initParams is InitializationParametersImp {
                let params = initParams as? InitializationParametersImp
                self.orgId = params?.orgId
                self.appId = params?.appId
                if let orgId = self.orgId {
                    self.org = String(orgId)
                }
                if let appId = self.appId {
                    self.app = String(appId)
                }
                self.prebidAPIKey = initParams.getPrebidAPIKey()
            }
            
            if UserDefaults.standard.string(forKey: "msp_user_id") == nil {
                self.fetchMSPUserId()
            }
            
            self.numInitWaitingForCallbacks = 1 //default vaule is 1 for prebid sdk is alwasys in the dependency
            for manager in adNetworkManagers {
                if let adNetworkAdapter = manager.getAdNetworkAdapter() {
                    self.adNetworkAdapterProvider.adNetworkManagerDict[adNetworkAdapter.getAdNetwork()] = manager
                    self.numInitWaitingForCallbacks += 1
                }
                
            }
            self.sdkInitListener = sdkInitListener
            var adapterInitListener = MSPAdapterInitListener()
            
            MSPAdConfigManager.shared.initAdConfig()
            for manager in adNetworkManagers {
                if let adNetworkAdapter = manager.getAdNetworkAdapter() {
                    self.adNetworkInitStartTime[adNetworkAdapter.getAdNetwork().rawValue] = Date().timeIntervalSince1970
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
            self.blockLatencyInMs = Int32((Date().timeIntervalSince1970 - initStartTime) * 1000)
        }
    }
    
    public class MSPAdapterInitListener: NSObject, AdapterInitListener {
        public func onComplete(adNetwork: AdNetwork, adapterInitStatus: AdapterInitStatus, message: String) {
            DispatchQueue.main.async {
                MSP.shared.numInitWaitingForCallbacks = MSP.shared.numInitWaitingForCallbacks - 1
                if let startTime = MSP.shared.adNetworkInitStartTime[adNetwork.rawValue] {
                    MSP.shared.adNetworkInitLatencyInMs[adNetwork.rawValue] = Int32((Date().timeIntervalSince1970 - startTime) * 1000)
                }
                if MSP.shared.numInitWaitingForCallbacks == 0 {
                    MSPLogger.shared.info(message: "MSP SDK is initialized successfully")
                    var totalCompleteTimeInMs: Int32?
                    if let initStartTime = MSP.shared.initStartTime {
                        totalCompleteTimeInMs = Int32((Date().timeIntervalSince1970 - initStartTime) * 1000)
                    }
                    MESMetricReporter.shared.logSDKInit(totalCompleteTimeInMs: totalCompleteTimeInMs, blockLatencyInMs: MSP.shared.blockLatencyInMs, adNetworkCompleteTimeInMs: MSP.shared.adNetworkInitLatencyInMs)
                    MSP.shared.sdkInitListener?.onComplete(status: .SUCCESS, message: "")
                }
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
    
    /// Shows the mediation debugger interface as a modal presentation.
    /// This method automatically finds the top-most view controller and presents the debugger modally.
    /// 
    /// - Note: This method can be called from anywhere in your app, regardless of the current view controller hierarchy.
    /// - Warning: The debugger will be presented modally and can be dismissed by the user.
    /// 
    /// ## Usage Example:
    /// ```swift
    /// MSP.shared.showMediationDebugger()
    /// ```
    public func showMediationDebugger() {
        DispatchQueue.main.async {
            if let topViewController = self.getTopViewController() {
                let debugViewController = DebugAdLoadViewController()
                let navigationController = UINavigationController(rootViewController: debugViewController)
                topViewController.present(navigationController, animated: true, completion: nil)
            }
        }
    }
    
    /// Shows the mediation debugger interface by pushing it onto the navigation stack.
    /// This method requires the caller to be embedded in a navigation controller.
    /// 
    /// - Parameter rootViewController: The view controller from which to push the debugger. 
    ///   This view controller must be embedded in a UINavigationController.
    /// - Note: If the rootViewController is not embedded in a navigation controller, this method will have no effect.
    /// - Warning: The debugger will be pushed onto the navigation stack and can be popped back by the user.
    /// 
    /// ## Usage Example:
    /// ```swift
    /// // From within a view controller that's embedded in a navigation controller
    /// MSP.shared.showMediationDebugger(from: self)
    /// ```
    public func showMediationDebugger(from rootViewController: UIViewController) {
        let debugViewController = DebugAdLoadViewController()
        rootViewController.navigationController?.pushViewController(debugViewController, animated: true)
    }
    
    /// Helper method to find the top-most view controller in the app's view hierarchy.
    /// This method traverses through presented view controllers, navigation controllers, and tab bar controllers.
    /// 
    /// - Returns: The top-most view controller, or nil if no view controller is found.
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        
        var topViewController = window.rootViewController
        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }
        
        if let navigationController = topViewController as? UINavigationController {
            topViewController = navigationController.visibleViewController
        }
        
        if let tabBarController = topViewController as? UITabBarController {
            topViewController = tabBarController.selectedViewController
        }
        
        return topViewController
    }
    
    public func updateLogSample(sampleRate: Double) {
        guard sampleRate.isFinite else {
            self.isLogSampled = false
            return
        }
        if sampleRate <= 0 {
            self.isLogSampled = false
            return
        }
        if sampleRate >= 1 {
            self.isLogSampled = true
            return
        }
        return self.isLogSampled = Double.random(in: 0..<1) < sampleRate
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
