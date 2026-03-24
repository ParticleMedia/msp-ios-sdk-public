import AppTrackingTransparency
import InmobiAdapter
import MSPCore
import MSPFacebookAdapter
import MSPGoogleAdapter
import MSPLiftoffAdapter
import MSPMolocoAdapter
import MSPNovaAdapter
import MSPiOSCore
import MintegralAdapter
import MobilefuseAdapter
import PubmaticAdapter
import UIKit
import UnityAdapter

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let mspInitParameters = InitializationParametersImp(
            prebidAPIKey: "af7ce3f9-462d-4df1-815f-09314bb87ca3",
            sourceApp: "0000000000",  // Your App's numeric ID on App Store
            orgId: 1061,
            appId: 1)
        mspInitParameters.params = [
            InitializationParametersCustomKeys.UNITY_APP_KEY: "8545d445",
            InitializationParametersCustomKeys.INMOBI_ACCOUNT_ID: "4028cb8b2c3a0b45012c406824e800ba",
            InitializationParametersCustomKeys.MINTEGRAL_APP_ID: "150180",
            InitializationParametersCustomKeys.MINTEGRAL_API_KEY: "7c22942b749fe6a6e361b675e96b3ee9",
            InitializationParametersCustomKeys.PUBMATIC_PUBLISHER_ID: "156276",
            InitializationParametersCustomKeys.PUBMATIC_PROFILE_IDS: [1165],
            InitializationParametersCustomKeys.PUBMATIC_STORE_URL:
                "https://itunes.apple.com/us/app/pubmatic-sdk-app/id1175273098?mt=8",
            InitializationParametersCustomKeys.MOLOCO_APP_KEY: "NEWSBREAK:dX2DtwJM9o9okqwZ",
            InitializationParametersCustomKeys.LIFTOFF_APP_ID: "6937f2485cdd890926d69668",
        ]
        //Note: for pubmatic ad you may need to config your NSAllowsArbitraryLoads key in App's Info.list to get a full experience, see details in https://help.pubmatic.com/openwrap/docs/home-get-started-with-ios-openwrap-sdk-as-primary-ad-sdk#app-transport-security-ats
        let adNetworkManagers: [AdNetworkManager] = [
            GoogleManager(), FacebookManager(), NovaManager(), UnityManager(), PubmaticManager(), MintegralManager(),
            MobilefuseManager(), InmobiManager(), MolocoManager(), LiftoffManager(),
        ]
        //MSP.shared.setNovaManager(novaManager: NovaManager())

        //MSP.shared.setGoogleManager(googleManager: GoogleManager())
        MSP.shared.bidLoaderProvider.googleQueryInfoFetcher = GoogleQueryInfoFetcherHelper()

        //MSP.shared.setMetaManager(metaManager: FacebookManager())
        MSP.shared.bidLoaderProvider.facebookBidTokenProvider = FacebookBidTokenProviderHelper()
        MSP.shared.bidLoaderProvider.molocoBidTokenProvider = MolocoBidTokenProviderHelper()
        MSP.shared.bidLoaderProvider.liftoffBidTokenProvider = LiftoffBidTokenProviderHelper()

        //MSP.shared.setUnityManager(unityManager: UnityManager())
        MSPLogger.shared.setLogLevel(level: MSPLogger.DEBUG)
        MSP.shared.ppid = "1234567"
        MSP.shared.initMSP(initParams: mspInitParameters, sdkInitListener: nil, adNetworkManagers: adNetworkManagers)
        window = UIWindow(frame: UIScreen.main.bounds)
        let rootVC = ViewController()
        window?.rootViewController = UINavigationController(rootViewController: rootVC)
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
}
