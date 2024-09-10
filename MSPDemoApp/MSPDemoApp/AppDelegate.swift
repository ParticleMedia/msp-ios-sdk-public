//
//  AppDelegate.swift
//  MSPDemoApp
//
//  Created by Huanzhi Zhang on 4/29/24.
//

import UIKit
//import shared
//import MSPiOSCore
import MSPCore
//import PrebidMobile
import GoogleAdapter
//import MetaAdapter
import NovaAdapter
import AppTrackingTransparency

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        let mspInitParameters = InitializationParametersImp(prebidAPIKey: "sggU8Y1UB6xara62G23qGdcOA8co2O4N",
                                                            prebidHostUrl: "https://prebid-server.newsbreak.com/openrtb2/auction",
                                                            sourceApp: "1132762804")
        MSP.shared.setNovaManager(novaManager: NovaManager())
        MSP.shared.setGoogleManager(googleManager: GoogleManager())
        
        // optional ad networks
        //MSP.shared.setGoogleManager(googleManager: GoogleManager())
        MSP.shared.bidLoaderProvider.googleQueryInfoFetcher = GoogleQueryInfoFetcherHelper()
        //MSP.shared.setMetaManager(metaManager: MetaManager())
        //MSP.shared.bidLoaderProvider.facebookBidTokenProvider = FacebookBidTokenProviderHelper()
        MSP.shared.initMSP(initParams: mspInitParameters, sdkInitListener: nil)
        
        window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.makeKeyAndVisible()
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if #available(iOS 14, *) {
                ATTrackingManager.requestTrackingAuthorization { result in
                    
                }
            } else {
                // Fallback on earlier versions
            }
        }
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

