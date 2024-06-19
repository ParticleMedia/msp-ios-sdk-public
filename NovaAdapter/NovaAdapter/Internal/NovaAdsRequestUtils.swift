import UIKit

struct NovaAdsRequestUtils {
    static var novaAdsBaseUri: String {
        return "https://business.newsbreak.com"
        //if NBTweaksDebugModeAPI() == .prod {
        //    return "https://business.newsbreak.com"
        //} else {
        //    return "http://ads.k8s.nb-stage.com"
        //}
    }

    static func placementParams(adUnitId: String, adType: NovaAdType, numberOfAds: Int) -> [String: String] {
        var params: [String: String] = [
            "format": adType.description,
            "ad_unit": adUnitId,
            "num_ads": "\(numberOfAds)",
        ]

        switch adType {
        case .appOpen:
            params["width"] = "\(UIScreen.main.bounds.width)"
            params["height"] = "\(UIScreen.main.bounds.height)"

        default:
            break
        }

        return params
    }

    static var appParams: [String: String] {
        var params = [String: String]()

        params["bundle"] = Bundle.main.bundleIdentifier
        /*
        params["cv"] = Bundle.main.bundleFullVersionString

        if let user = HpEngine.sharedInstance().user {
            params["user_id"] = user.uid
            params["profile_id"] = user.pid
            params["weather"] = user.weatherCondition()
            if user.privacyHasCCPA {
                if user.privacyCCPADoNotSell {
                    params["us_privacy"] = "1YY-"
                } else {
                    params["us_privacy"] = "1YN-"
                }
            } else {
                params["us_privacy"] = "1---"
            }
        }
         */

        //params["session_id"] = "\(HpEngine.sharedInstance().nbSessionId)"
        //params["device_id"] = FreshInstallStatusUtils.installDeviceID()

        //params["postal_code"] = LocationServiceManager.shared.userDefaultSelectLocationPostcode()
        //params["city"] = LocationServiceManager.shared.userDefaultSelectLocation()
        //params["state"] = LocationServiceManager.shared.userDefaultSelectLocationState()

        //params["language"] = AdsRequestUtils.appLanguage

        return params
    }

    static var deviceParams: [String: String] {
        var params = [String: String]()

        params["make"] = "Apple"
        params["brand"] = "Apple"
        /*
        params["model"] = UIDevice.nb_deviceModelMarketName

        params["os"] = Device.current.systemName
        params["osv"] = Device.current.systemVersion

        params["lang"] = AdsRequestUtils.deviceLanguage

        if let info = CTTelephonyNetworkInfo().serviceSubscriberCellularProviders?.values.first(where: { carrierInfo in
            carrierInfo.carrierName?.isEmpty == false
        }) {
            params["carrier"] = info.carrierName
        }

        params["ct"] = NBReachability.shared.networkString

        params["latitude"] = LocationServiceManager.shared.userDefaultSelectionLocationLat()
        params["longitude"] = LocationServiceManager.shared.userDefaultSelectionLocationLong()

        params["idfa"] = IDFAUtils.idfa()
        params["lmt"] = IDFAUtils.isIDFAAuthorized() ? "1" : "0"
         */
        return params
    }

    static func mediaParams(channelId: String?, channelName: String?, docId: String?, opportunityId: String?) -> [String: String] {
        var params = [String: String]()

        params["x_channel_id"] = channelId
        params["x_channel_name"] = channelName
        params["x_doc_id"] = docId
        params["x_uuid"] = opportunityId

        return params
    }

    static func dedupeParams(adUnitId: String) -> [String: String] {
        var params = [String: String]()

        let dedupeKeys = NovaDedupeManager.shared.getServerDedupeKeys(first: 3, prioritizedBy: adUnitId)
        let dedupeInfo = dedupeKeys.joined(separator: ";")

        if !dedupeInfo.isEmpty {
            params["dedupe_info"] = dedupeInfo
        }

        return params
    }
}

