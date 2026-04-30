import Foundation
import MSPiOSCore

enum PrebidHost: String {
    case prebidHostInternal = "https://prebid-server.newsbreak.com"
    case prebidHostExternal = "https://msp.newsbreak.com"
}

struct AppProfile {
    let appName: String
    let prebidAPIKey: String
    let sourceApp: String
    let orgId: Int64
    let appId: Int64
    let prebidHost: PrebidHost
    let parameters: [String: Any]
    let bannerPlacements: [String]
    let nativePlacements: [String]
    let interstitialPlacements: [String]
    let rewardedPlacements: [String]

    // MARK: - Persistence

    private static let selectedIndexKey = "selectedAppProfileIndex"

    static var selectedIndex: Int {
        get { UserDefaults.standard.integer(forKey: selectedIndexKey) }
        set { UserDefaults.standard.set(newValue, forKey: selectedIndexKey) }
    }

    static var current: AppProfile {
        let index = selectedIndex
        return index < profiles.count ? profiles[index] : profiles[0]
    }

    // MARK: - Profiles

    private static let DEMO_APP = AppProfile(
        appName: "Demo App",
        prebidAPIKey: "af7ce3f9-462d-4df1-815f-09314bb87ca3",
        sourceApp: "0000000000",
        orgId: 1061,
        appId: 1,
        prebidHost: .prebidHostExternal,
        parameters: [
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
            InitializationParametersCustomKeys.APPLOVIN_SDK_KEY:
                "6KrA5SQHFTBpGDUU4FeLIZGxGFmd1rORGfr5xlrJIMeXO8pdvuKPQO4WAfQpEZ4cXAOXoeSJJRoX0zcD4qBzak",
        ],
        bannerPlacements: [
            "demoapp-ios-foryou-test-liftoff-banner",
            "demo-ios-article-top",
            "demo-ios-foryou-large-google-c2s",
            "demoapp-ios-applovin-banner-test",
        ],
        nativePlacements: [
            "demo-ios-foryou-large",
            "demoapp-ios-foryou-test-liftoff-native",
            "demo-ios-native-google-c2s-test",
            "demo-ios-native-video-google-c2s-test",
            "demo-ios-article-top-client-bidding",
            "demoapp-ios-applovin-native-test",
        ],
        interstitialPlacements: [
            "demo-ios-launch-fullscreen",
            "demoapp-ios-foryou-test-liftoff-interstitial",
            "demo-ios-launch-fullscreen-google-c2s",
            "demoapp-ios-applovin-interstitial-test",
        ],
        rewardedPlacements: [
            "demo-ios-rewarded",
            "demoapp-ios-applovin-rewarded-test",
        ]
    )

    private static let NEWSBREAK = AppProfile(
        appName: "NewsBreak",
        prebidAPIKey: "sggU8Y1UB6xara62G23qGdcOA8co2O4N",
        sourceApp: "1132762804",
        orgId: 0,
        appId: 1,
        prebidHost: .prebidHostInternal,
        parameters: [
            InitializationParametersCustomKeys.MOLOCO_APP_KEY: "NEWSBREAK:OO8T2JEYiGFY4ftI",
            InitializationParametersCustomKeys.LIFTOFF_APP_ID: "69437e3201d2a42bf6087b94",
            InitializationParametersCustomKeys.AMAZON_APP_KEY: "75b4cb56-1bf5-4732-9918-d22a1c78b194",
        ],
        bannerPlacements: [
            "msp-ios-article-top-display-prod"
        ],
        nativePlacements: [
            "msp-ios-foryou-large-display-prod3",
            "msp-ios-article-inside-display-prod3",
            "msp-ios-article-inside-native-prod",
        ],
        interstitialPlacements: [
            "msp-ios-launch-fullscreen-interstitial-prod2"
        ],
        rewardedPlacements: [
            "msp-ios-drama-fullscreen-interstitial-prod",
            "msp-ios-drama-reward-video-prod",
            "demo-ios-rewarded",
        ]
    )

    private static let SCOOPZ = AppProfile(
        appName: "Scoopz",
        prebidAPIKey: "9bb25369-6ae9-409d-8df9-ee2b1398430f",
        sourceApp: "6449206831",
        orgId: 0,
        appId: 2,
        prebidHost: .prebidHostInternal,
        parameters: [
            InitializationParametersCustomKeys.UNITY_APP_KEY: "8545d445",
            InitializationParametersCustomKeys.INMOBI_ACCOUNT_ID: "3ef8dd9e9d5b4080ad1682510980b643",
            InitializationParametersCustomKeys.MINTEGRAL_APP_ID: "150180",
            InitializationParametersCustomKeys.MINTEGRAL_API_KEY: "7c22942b749fe6a6e361b675e96b3ee9",
            InitializationParametersCustomKeys.PUBMATIC_PUBLISHER_ID: "166296",
            InitializationParametersCustomKeys.PUBMATIC_PROFILE_IDS: [16505],
            InitializationParametersCustomKeys.PUBMATIC_STORE_URL:
                "https://apps.apple.com/us/app/scoopz-real-life-real-video/id6449206831",
            InitializationParametersCustomKeys.MOLOCO_APP_KEY: "NEWSBREAK:dX2DtwJM9o9okqwZ",
            InitializationParametersCustomKeys.LIFTOFF_APP_ID: "69437dbc01d2a42bf6087b8f",
        ],
        bannerPlacements: [
            "scoopz-ios-foryou-test-liftoff-inline",
            "scoopz-ios-foryou-prod",
            "scoopz-ios-foryou-test-nova",
        ],
        nativePlacements: [
            "scoopz-ios-foryou-test-moloco-native",
            "scoopz-ios-foryou-test-liftoff-native",
            "scoopz-ios-foryou-prod",
            "scoopz-ios-foryou-test-nova",
        ],
        interstitialPlacements: [
            "scoopz-ios-launch-test-moloco",
            "scoopz-ios-launch-prod",
        ],
        rewardedPlacements: [
            "scoopz-ios-dramareward-prod"
        ]
    )

    static let profiles: [AppProfile] = [
        DEMO_APP, NEWSBREAK, SCOOPZ,
    ]
}
