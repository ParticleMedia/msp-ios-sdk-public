import UIKit
import MSPCore
import GoogleAdapter
import NovaAdapter
import UnityAdapter
import PubmaticAdapter
import MintegralAdapter
import MobilefuseAdapter
import InmobiAdapter
import AppTrackingTransparency
import MSPiOSCore

import FacebookAdapter


@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        let mspInitParameters = InitializationParametersImp(prebidAPIKey: "af7ce3f9-462d-4df1-815f-09314bb87ca3",
                                                            sourceApp: "0000000000", // Your App's numeric ID on App Store
                                                            orgId: 1061,
                                                            appId: 1)
        mspInitParameters.params = [InitializationParametersCustomKeys.UNITY_APP_KEY: "8545d445",
                                    InitializationParametersCustomKeys.INMOBI_ACCOUNT_ID:"4028cb8b2c3a0b45012c406824e800ba",
                                    InitializationParametersCustomKeys.MINTEGRAL_APP_ID:"150180",
                                    InitializationParametersCustomKeys.MINTEGRAL_API_KEY:"7c22942b749fe6a6e361b675e96b3ee9",
                                    InitializationParametersCustomKeys.PUBMATIC_PUBLISHER_ID: "156276",
                                    InitializationParametersCustomKeys.PUBMATIC_PROFILE_IDS: [1165],
                                    InitializationParametersCustomKeys.PUBMATIC_STORE_URL: "https://itunes.apple.com/us/app/pubmatic-sdk-app/id1175273098?mt=8"]
        //Note: for pubmatic ad you may need to config your NSAllowsArbitraryLoads key in App's Info.list to get a full experience, see details in https://help.pubmatic.com/openwrap/docs/home-get-started-with-ios-openwrap-sdk-as-primary-ad-sdk#app-transport-security-ats
        var adNetworkManagers = [NovaManager(), GoogleManager(), FacebookManager(), UnityManager(), PubmaticManager(), MintegralManager(), MobilefuseManager(), InmobiManager()]
        //MSP.shared.setNovaManager(novaManager: NovaManager())
        
        //MSP.shared.setGoogleManager(googleManager: GoogleManager())
        MSP.shared.bidLoaderProvider.googleQueryInfoFetcher = GoogleQueryInfoFetcherHelper()
        
        //MSP.shared.setMetaManager(metaManager: FacebookManager())
        MSP.shared.bidLoaderProvider.facebookBidTokenProvider = FacebookBidTokenProviderHelper()
        
        //MSP.shared.setUnityManager(unityManager: UnityManager())
        MSPLogger.shared.setLogLevel(level: MSPLogger.DEBUG)
        MSP.shared.ppid = "1234567"
        MSP.shared.initMSP(initParams: mspInitParameters, sdkInitListener: nil, adNetworkManagers: adNetworkManagers)
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

