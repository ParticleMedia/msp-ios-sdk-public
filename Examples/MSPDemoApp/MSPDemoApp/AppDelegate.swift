import AppTrackingTransparency
import InmobiAdapter
import MSPApplovinMaxAdapter
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

    private let fbTestDeviceRegistrar = FBTestDeviceRegistrar()

    private let adNetworkManagers: [AdNetworkManager] = [
        GoogleManager(), FacebookManager(), NovaManager(), UnityManager(), PubmaticManager(), MintegralManager(),
        MobilefuseManager(), InmobiManager(), MolocoManager(), LiftoffManager(), ApplovinMaxManager(),
    ]

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Must be called before initializeMSP to capture FB device hash logs
        // emitted during FB SDK's first initialization.
        fbTestDeviceRegistrar.setup()
        initializeMSP(with: AppProfile.current)
        window = UIWindow(frame: UIScreen.main.bounds)
        resetRootViewController()
        window?.makeKeyAndVisible()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if #available(iOS 14, *) {
                ATTrackingManager.requestTrackingAuthorization { _ in }
            }
        }

        return true
    }

    func reinitializeApp(with profile: AppProfile) {
        initializeMSP(with: profile)
        resetRootViewController()
    }

    // MARK: - Private

    private func initializeMSP(with profile: AppProfile) {
        //Note: for pubmatic ad you may need to config your NSAllowsArbitraryLoads key in App's Info.list to get a full experience, see details in https://help.pubmatic.com/openwrap/docs/home-get-started-with-ios-openwrap-sdk-as-primary-ad-sdk#app-transport-security-ats
        MSP.shared.prebidHost = profile.prebidHost.rawValue

        let mspInitParameters = InitializationParametersImp(
            prebidAPIKey: profile.prebidAPIKey,
            sourceApp: profile.sourceApp,
            orgId: profile.orgId,
            appId: profile.appId)
        mspInitParameters.params = profile.parameters

        //MSP.shared.setGoogleManager(googleManager: GoogleManager())
        MSP.shared.bidLoaderProvider.googleQueryInfoFetcher = GoogleQueryInfoFetcherHelper()

        //MSP.shared.setMetaManager(metaManager: FacebookManager())
        MSP.shared.bidLoaderProvider.facebookBidTokenProvider = FacebookBidTokenProviderHelper()
        MSP.shared.bidLoaderProvider.molocoBidTokenProvider = MolocoBidTokenProviderHelper()
        MSP.shared.bidLoaderProvider.liftoffBidTokenProvider = LiftoffBidTokenProviderHelper()

        MSPLogger.shared.setLogLevel(level: MSPLogger.DEBUG)
        MSP.shared.ppid = "1234567"
        MSP.shared.initMSP(initParams: mspInitParameters, sdkInitListener: nil, adNetworkManagers: adNetworkManagers)
    }

    private func resetRootViewController() {
        window?.rootViewController = UINavigationController(rootViewController: HomeViewController())
    }
}
