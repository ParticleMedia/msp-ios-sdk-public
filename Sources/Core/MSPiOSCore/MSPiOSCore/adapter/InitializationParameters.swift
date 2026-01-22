//
//  InitializationParameters.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/12/24.
//

import Foundation

public protocol InitializationParameters: AdapterParameters {
    func getPrebidAPIKey() -> String

    func getPrebidHostUrl() -> String

    func getAppStoreId() -> String?
}

public struct InitializationParametersCustomKeys {
    public static let UNITY_APP_KEY = "unityAppKey"
    public static let INMOBI_ACCOUNT_ID = "inmobiAccountId"
    public static let MINTEGRAL_APP_ID = "mintegralAppId"
    public static let MINTEGRAL_API_KEY = "mintegralApiKey"
    public static let PUBMATIC_PUBLISHER_ID = "pubmaticPublisherId"
    public static let PUBMATIC_PROFILE_IDS = "pubmaticProfileIds"
    public static let PUBMATIC_STORE_URL = "pubmaticStoreUrl"
    public static let AMAZON_APP_KEY = "amazonAppKey"
    public static let MOLOCO_APP_KEY = "molocoAppKey"
    public static let LIFTOFF_APP_ID = "liftoffAppId"
}
