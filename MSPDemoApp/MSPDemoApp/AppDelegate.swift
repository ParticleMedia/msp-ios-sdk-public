//
//  AppDelegate.swift
//  MSPDemoApp
//
//  Created by Huanzhi Zhang on 4/29/24.
//

import UIKit
import shared
//import MSPiOSCore
import MSPCore
import PrebidMobile
import GoogleAdapter
import MetaAdapter
import NovaAdapter
import AppTrackingTransparency

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        //MSPHelper.initMSP()
        //MSPManager().adNetworkAdapterProvider = MSPAdNetworkAdapterProvider()
        //MSPManager.shared.adNetworkAdapterProvider = MSPAdNetworkAdapterProvider()
        //[[Prebid shared] setCustomPrebidServerWithUrl: [NSString stringWithFormat:@"%@openrtb2/auction", prebidHost] error:nil];
        //[Prebid shared].prebidServerAccountId =  @"sggU8Y1UB6xara62G23qGdcOA8co2O4N_debug";
        let mspInitParameters = InitializationParametersImp(prebidAPIKey: "sggU8Y1UB6xara62G23qGdcOA8co2O4N",
                                                            prebidHostUrl: "https://prebid-server.newsbreak.com/openrtb2/auction")
        MSPHelper.shared.setNovaManager(novaManager: NovaManager())
        MSPHelper.shared.setGoogleManager(googleManager: GoogleManager())
        MSPHelper.shared.bidLoaderProvider.googleQueryInfoFetcher = GoogleQueryInfoFetcherHelper()
        MSPHelper.shared.setMetaManager(metaManager: MetaManager())
        MSPHelper.shared.bidLoaderProvider.facebookBidTokenProvider = FacebookBidTokenProviderHelper()
        MSPHelper.shared.initMSP(initParams: mspInitParameters, sdkInitListener: nil)
        
        window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.makeKeyAndVisible()
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { result in
                print(result.rawValue)
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

